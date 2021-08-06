//
//  Channel.swift
//  Shout
//
//  Created by Jake Heiser on 3/4/18.
//

// import CSSH
import struct Foundation.Data
import struct Foundation.URL

/// Direct bindings to libssh2_channel
public class Channel {
    // MARK: Lifecycle

    private init(cSession: OpaquePointer, cChannel: OpaquePointer) {
        self.cSession = cSession
        self.cChannel = cChannel
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif
        libssh2_channel_free(cChannel)
        session = nil
    }

    // MARK: Public

    public var cancelled = false
    public var session: Session?

    public func cancel() throws {
        cancelled = true
        _ = write(data: Data([3]), length: 1)
        try sendEOF()
        try close()
        try waitClosed()
    }

    // MARK: Internal

    static let windowDefault: UInt32 = 2 * 1024 * 1024
    static let packetDefaultSize: UInt32 = 32768
    static let readBufferSize = 0x4000

    static func createForCommand(cSession: OpaquePointer) throws -> Channel {
        guard let cChannel = libssh2_channel_open_ex(
            cSession,
            Channel.session,
            UInt32(Channel.session.count),
            Channel.windowDefault,
            Channel.packetDefaultSize,
            nil,
            0
        )
        else {
            throw SSHError.mostRecentError(session: cSession, backupMessage: "libssh2_channel_open_ex failed")
        }
        return Channel(cSession: cSession, cChannel: cChannel)
    }

    static func createForSCP(cSession: OpaquePointer, fileSize: Int64, remotePath: String, permissions: FilePermissions) throws -> Channel {
        guard let cChannel = libssh2_scp_send64(cSession, remotePath, permissions.rawValue, fileSize, 0, 0) else {
            throw SSHError.mostRecentError(session: cSession, backupMessage: "libssh2_scp_send64 failed")
        }
        return Channel(cSession: cSession, cChannel: cChannel)
    }

    func requestPty(type: String) throws {
        let code = libssh2_channel_request_pty_ex(
            cChannel,
            type,
            UInt32(type.utf8.count),
            nil,
            0,
            LIBSSH2_TERM_WIDTH,
            LIBSSH2_TERM_HEIGHT,
            LIBSSH2_TERM_WIDTH_PX,
            LIBSSH2_TERM_WIDTH_PX
        )
        try SSHError.check(code: code, session: cSession)
    }

    func exec(command: String) throws {
        let code = libssh2_channel_process_startup(
            cChannel,
            Channel.exec,
            UInt32(Channel.exec.count),
            command,
            UInt32(command.count)
        )
        try SSHError.check(code: code, session: cSession)
    }

    func readData() -> ReadWriteProcessor.ReadResult {
        let result = libssh2_channel_read_ex(cChannel, 0, &readBuffer, Channel.readBufferSize)
        return ReadWriteProcessor.processRead(result: result, buffer: &readBuffer, session: cSession)
    }

    func write(data: Data, length: Int, to stream: Int32 = 0) -> ReadWriteProcessor.WriteResult {
        let result: Result<Int, SSHError> = data.withUnsafeBytes {
            guard let unsafePointer = $0.bindMemory(to: Int8.self).baseAddress else {
                return .failure(SSHError.genericError("Channel write failed to bind memory"))
            }
            return .success(libssh2_channel_write_ex(cChannel, stream, unsafePointer, length))
        }
        switch result {
        case let .failure(error):
            return .error(error)
        case let .success(value):
            return ReadWriteProcessor.processWrite(result: value, session: cSession)
        }
    }

    func sendEOF() throws {
        let code = libssh2_channel_send_eof(cChannel)
        try SSHError.check(code: code, session: cSession)
    }

    func waitEOF() throws {
        let code = libssh2_channel_wait_eof(cChannel)
        try SSHError.check(code: code, session: cSession)
    }

    func close() throws {
        let code = libssh2_channel_close(cChannel)
        try SSHError.check(code: code, session: cSession)
    }

    func waitClosed() throws {
        let code = libssh2_channel_wait_closed(cChannel)
        try SSHError.check(code: code, session: cSession)
    }

    func exitStatus() -> Int32 {
        libssh2_channel_get_exit_status(cChannel)
    }

    // MARK: Private

    private static let session = "session"
    private static let exec = "exec"

    private let cSession: OpaquePointer
    private let cChannel: OpaquePointer
    private var readBuffer = [Int8](repeating: 0, count: Channel.readBufferSize)
}
