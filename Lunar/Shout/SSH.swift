//
//  SSH.swift
//  Shout
//
//  Created by Jake Heiser on 3/4/18.
//

import Foundation
import Socket

/// Manages an SSH session
public class SSH {
    // MARK: Lifecycle

    /// Creates a new SSH session
    ///
    /// - Parameters:
    ///   - host: the host to connect to
    ///   - port: the port to connect to; default 22
    /// - Throws: SSHError if the SSH session couldn't be created
    public init(host: String, port: Int32 = 22) throws {
        self.host = host
        self.port = port

        sock = try Socket.create()
        session = try Session()

        session.blocking = 1
        try sock.connect(to: host, port: port)
        try session.handshake(over: sock)
    }

    // MARK: Public

    public enum PtyType: String {
        case vanilla
        case vt100
        case vt102
        case vt220
        case ansi
        case xterm
    }

    public let host: String
    public let port: Int32

    public var ptyType: PtyType?

    /// Connects to a remote server and opens an SSH session
    ///
    /// - Parameters:
    ///   - host: the host to connect to
    ///   - port: the port to connect to; default 22
    ///   - username: the username to login with
    ///   - authMethod: the authentication method to use while logging in
    ///   - execution: the block executed with the open, authenticated SSH session
    /// - Throws: SSHError if the session fails at any point
    public static func connect(
        host: String,
        port: Int32 = 22,
        username: String,
        authMethod: SSHAuthMethod,
        execution: (_ ssh: SSH) throws -> Void
    ) throws {
        let ssh = try SSH(host: host, port: port)
        try ssh.authenticate(username: username, authMethod: authMethod)
        try execution(ssh)
    }

    /// Authenticate the session using a public/private key pair
    ///
    /// - Parameters:
    ///   - username: the username to login with
    ///   - privateKey: the path to the private key
    ///   - publicKey: the path to the public key; defaults to private key path + ".pub"
    ///   - passphrase: the passphrase encrypting the key; defaults to nil
    /// - Throws: SSHError if authentication fails
    public func authenticate(username: String, privateKey: String, publicKey: String? = nil, passphrase: String? = nil) throws {
        let key = SSHKey(privateKey: privateKey, publicKey: publicKey, passphrase: passphrase)
        try authenticate(username: username, authMethod: key)
    }

    /// Authenticate the session using a password
    ///
    /// - Parameters:
    ///   - username: the username to login with
    ///   - password: the user's password
    /// - Throws: SSHError if authentication fails
    public func authenticate(username: String, password: String) throws {
        try authenticate(username: username, authMethod: SSHPassword(password))
    }

    /// Authenticate the session using the SSH agent
    ///
    /// - Parameter username: the username to login with
    /// - Throws: SSHError if authentication fails
    public func authenticateByAgent(username: String) throws {
        try authenticate(username: username, authMethod: SSHAgent())
    }

    /// Authenticate the session using the given authentication method
    ///
    /// - Parameters:
    ///   - username: the username to login with
    ///   - authMethod: the authentication method to use
    /// - Throws: SSHError if authentication fails
    public func authenticate(username: String, authMethod: SSHAuthMethod) throws {
        try authMethod.authenticate(ssh: self, username: username)
    }

    /// Execute a command on the remote server
    ///
    /// - Parameters:
    ///   - command: the command to execute
    ///   - silent: whether or not to execute the command silently; defaults to false
    /// - Returns: exit code of the command
    /// - Throws: SSHError if the command couldn't be executed
    @discardableResult
    public func execute(_ command: String, silent: Bool = false) throws -> Int32 {
        try execute(command, output: { output in
            if silent == false {
                print(output, terminator: "")
                fflush(stdout)
            }
        })
    }

    /// Execute a command on the remote server and capture the output
    ///
    /// - Parameter command: the command to execute
    /// - Returns: a tuple with the exit code of the command and the output of the command
    /// - Throws: SSHError if the command couldn't be executed
    public func capture(_ command: String) throws -> (status: Int32, output: String) {
        var ongoing = ""
        let status = try execute(command) { output in
            ongoing += output
        }
        return (status, ongoing)
    }

    /// Execute a command on the remote server
    ///
    /// - Parameters:
    ///   - command: the command to execute
    ///   - output: block handler called every time a chunk of command output is received
    /// - Returns: exit code of the command
    /// - Throws: SSHError if the command couldn't be executed
    public func execute(
        _ command: String,
        onChannelOpened: ((Channel) -> Void)? = nil,
        output: (_ output: String) -> Void
    ) throws -> Int32 {
        let channel = try session.openCommandChannel()

        if let ptyType = ptyType {
            try channel.requestPty(type: ptyType.rawValue)
        }

        if let callback = onChannelOpened {
            channel.session = session
            callback(channel)
        }

        try channel.exec(command: command)

        var dataLeft = true
        while dataLeft, !channel.cancelled {
            switch channel.readData() {
            case let .data(data):
                guard let str = String(data: data, encoding: .utf8) else {
                    throw SSHError.genericError("SSH failed to create string using UTF8 encoding")
                }
                output(str)
            case .done:
                dataLeft = false
            case .eagain:
                break
            case let .error(error):
                throw error
            }
        }

        if !channel.cancelled {
            try channel.close()
        }

        return channel.exitStatus()
    }

    /// Upload a file from the local device to the remote server
    ///
    /// - Parameters:
    ///   - localURL: the path to the existing file on the local device
    ///   - remotePath: the location on the remote server whether the file should be uploaded to
    ///   - permissions: the file permissions to create the new file with; defaults to FilePermissions.default
    /// - Throws: SSHError if local file can't be read or upload fails
    @discardableResult
    public func sendFile(localURL: URL, remotePath: String, permissions: FilePermissions = .default) throws -> Int32 {
        guard let resources = try? localURL.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = resources.fileSize,
              let inputStream = InputStream(url: localURL)
        else {
            throw SSHError.genericError("couldn't open file at \(localURL)")
        }

        let channel = try session.openSCPChannel(fileSize: Int64(fileSize), remotePath: remotePath, permissions: permissions)

        inputStream.open()
        defer { inputStream.close() }

        let bufferSize = Int(Channel.packetDefaultSize)
        var buffer = Data(capacity: bufferSize)

        while inputStream.hasBytesAvailable {
            let bytesRead: Int = try buffer.withUnsafeMutableBytes {
                guard let pointer = $0.bindMemory(to: UInt8.self).baseAddress else {
                    throw SSHError.genericError("SSH write failed to bind buffer memory")
                }
                return inputStream.read(pointer, maxLength: bufferSize)
            }

            if bytesRead == 0 { break }

            var bytesSent = 0
            while bytesSent < bytesRead {
                let chunk = bytesSent == 0 ? buffer : buffer.advanced(by: bytesSent)
                switch channel.write(data: chunk, length: bytesRead - bytesSent) {
                case let .written(count):
                    bytesSent += count
                case .eagain:
                    break
                case let .error(error):
                    throw error
                }
            }
        }

        try channel.sendEOF()
        try channel.waitEOF()
        try channel.close()
        try channel.waitClosed()

        return channel.exitStatus()
    }

    /// Open an SFTP session with the remote server
    ///
    /// - Returns: the opened SFTP session
    /// - Throws: SSHError if an SFTP session could not be opened
    public func openSftp() throws -> SFTP {
        try session.openSftp()
    }

    // MARK: Internal

    let session: Session

    // MARK: Private

    private let sock: Socket
}
