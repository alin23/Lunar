//
//  SFTP.swift
//  Shout
//
//  Created by Vladislav Alexeev on 6/20/18.
//

import Foundation
// import CSSH

/// Manages an SFTP session
public class SFTP {
    init(session: Session, cSession: OpaquePointer) throws {
        guard let sftpSession = libssh2_sftp_init(cSession) else {
            throw SSHError.mostRecentError(session: cSession, backupMessage: "libssh2_sftp_init failed")
        }
        self.cSession = cSession
        self.sftpSession = sftpSession
        self.session = session
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif
        libssh2_sftp_shutdown(sftpSession)
    }

    /// Download a file from the remote server to the local device
    ///
    /// - Parameters:
    ///   - remotePath: the path to the existing file on the remote server to download
    ///   - localURL: the location on the local device whether the file should be downloaded to
    /// - Throws: SSHError if file can't be created or download fails
    public func download(remotePath: String, localURL: URL) throws {
        let sftpHandle = try SFTPHandle(
            cSession: cSession,
            sftpSession: sftpSession,
            remotePath: remotePath,
            flags: LIBSSH2_FXF_READ,
            mode: 0
        )

        guard FileManager.default.createFile(atPath: localURL.path, contents: nil, attributes: nil),
              let fileHandle = try? FileHandle(forWritingTo: localURL)
        else {
            throw SSHError.genericError("couldn't create file at \(localURL.path)")
        }

        defer { fileHandle.closeFile() }

        var dataLeft = true
        while dataLeft {
            switch sftpHandle.read() {
            case let .data(data):
                fileHandle.write(data)
            case .done:
                dataLeft = false
            case .eagain:
                break
            case let .error(error):
                throw error
            }
        }
    }

    /// Upload a file from the local device to the remote server
    ///
    /// - Parameters:
    ///   - localURL: the path to the existing file on the local device
    ///   - remotePath: the location on the remote server whether the file should be uploaded to
    ///   - permissions: the file permissions to create the new file with; defaults to FilePermissions.default
    /// - Throws: SSHError if local file can't be read or upload fails
    public func upload(localURL: URL, remotePath: String, permissions: FilePermissions = .default) throws {
        let data = try Data(contentsOf: localURL, options: .alwaysMapped)
        try upload(data: data, remotePath: remotePath, permissions: permissions)
    }

    /// Upload data to a file on the remote server
    ///
    /// - Parameters:
    ///   - string: String to be uploaded as a file
    ///   - remotePath: the location on the remote server whether the file should be uploaded to
    ///   - permissions: the file permissions to create the new file with; defaults to FilePermissions.default
    /// - Throws: SSHError if string is not valid or upload fails
    public func upload(string: String, remotePath: String, permissions: FilePermissions = .default) throws {
        guard let data = string.data(using: .utf8) else {
            throw SSHError.genericError("Unable to convert string to utf8 data")
        }
        try upload(data: data, remotePath: remotePath, permissions: permissions)
    }

    /// Upload data to a file on the remote server
    ///
    /// - Parameters:
    ///   - data: Data to be uploaded as a file
    ///   - remotePath: the location on the remote server whether the file should be uploaded to
    ///   - permissions: the file permissions to create the new file with; defaults to FilePermissions.default
    /// - Throws: SSHError if upload fails
    public func upload(data: Data, remotePath: String, permissions: FilePermissions = .default) throws {
        let sftpHandle = try SFTPHandle(
            cSession: cSession,
            sftpSession: sftpSession,
            remotePath: remotePath,
            flags: LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT,
            mode: LIBSSH2_SFTP_S_IFREG | permissions.rawValue
        )

        var offset = 0
        while offset < data.count {
            let upTo = Swift.min(offset + SFTPHandle.bufferSize, data.count)
            let subdata = data.subdata(in: offset ..< upTo)
            if subdata.count > 0 {
                switch sftpHandle.write(subdata) {
                case let .written(bytesSent):
                    offset += bytesSent
                case .eagain:
                    break
                case let .error(error):
                    throw error
                }
            }
        }
    }

    /// Create a folder on the remote server
    ///
    /// - Parameters:
    ///   - remotePath: the path for the folder, which should be created
    /// - Throws: SSHError if folder can't be created
    public func createDirectory(_ path: String) throws {
        let result = path.withCString { (pointer: UnsafePointer<Int8>) -> Int32 in
            libssh2_sftp_mkdir_ex(
                sftpSession,
                pointer,
                UInt32(strlen(pointer)),
                Int(LIBSSH2_SFTP_S_IRWXU | LIBSSH2_SFTP_S_IRGRP | LIBSSH2_SFTP_S_IXGRP | LIBSSH2_SFTP_S_IROTH | LIBSSH2_SFTP_S_IXOTH)
            )
        }
        try handleSFTPCommandResult(result)
    }

    /// Rename a file on the remote server
    ///
    /// - Parameters:
    ///   - src: the (old) path of the file, which should be renamed
    ///   - dest: the new path of the file
    ///   - override: set to true, if rename should override if there is already a file on dest path
    /// - Throws: SSHError if file can't be renamed
    public func rename(src: String, dest: String, override: Bool) throws {
        var flag = Int(LIBSSH2_SFTP_RENAME_OVERWRITE)
        if !override { flag = 0 }

        let result = src.withCString { (srcPointer: UnsafePointer<Int8>) -> Int32 in
            dest.withCString { (destPointer: UnsafePointer<Int8>) -> Int32 in
                libssh2_sftp_rename_ex(sftpSession, srcPointer, UInt32(strlen(srcPointer)), destPointer, UInt32(strlen(destPointer)), flag)
            }
        }
        try handleSFTPCommandResult(result)
    }

    /// Remove a file on the remote server
    ///
    /// - Parameters:
    ///   - remotePath: the path of the file, which should be removed
    /// - Throws: SSHError if file can't be deleted
    public func removeFile(_ path: String) throws {
        let result = path.withCString { (pointer: UnsafePointer<Int8>) -> Int32 in
            libssh2_sftp_unlink_ex(sftpSession, pointer, UInt32(strlen(pointer)))
        }
        try handleSFTPCommandResult(result)
    }

    /// Remove a folder on the remote server
    ///
    /// - Parameters:
    ///   - remotePath: the path of the folder, which should be removed
    /// - Throws: SSHError if folder can't be deleted
    public func removeDirectory(_ path: String) throws {
        let result = path.withCString { (pointer: UnsafePointer<Int8>) -> Int32 in
            libssh2_sftp_rmdir_ex(sftpSession, pointer, UInt32(strlen(pointer)))
        }
        try handleSFTPCommandResult(result)
    }

    public func listFiles(in directory: String) throws -> [String: FileAttributes] {
        let sftpHandle = try SFTPHandle(
            cSession: cSession,
            sftpSession: sftpSession,
            remotePath: directory,
            flags: LIBSSH2_FXF_READ,
            mode: 0,
            openType: LIBSSH2_SFTP_OPENDIR
        )

        var files = [String: FileAttributes]()
        var attrs = LIBSSH2_SFTP_ATTRIBUTES()

        var dataLeft = true
        while dataLeft {
            switch sftpHandle.readDir(&attrs) {
            case let .data(data):
                guard let name = String(data: data, encoding: .utf8) else {
                    throw SSHError.genericError("unable to convert data to utf8 string")
                }
                files[name] = FileAttributes(attributes: attrs)
            case .done:
                dataLeft = false
            case .eagain:
                break
            case let .error(error):
                throw error
            }
        }
        return files
    }

    /// Direct bindings to libssh2_sftp
    private class SFTPHandle {
        init(
            cSession: OpaquePointer,
            sftpSession: OpaquePointer,
            remotePath: String,
            flags: Int32,
            mode: Int32,
            openType: Int32 = LIBSSH2_SFTP_OPENFILE
        ) throws {
            guard let sftpHandle = libssh2_sftp_open_ex(
                sftpSession,
                remotePath,
                UInt32(remotePath.count),
                UInt(flags),
                Int(mode),
                openType
            ) else {
                throw SSHError.mostRecentError(session: cSession, backupMessage: "libssh2_sftp_open_ex failed")
            }
            self.cSession = cSession
            self.sftpHandle = sftpHandle
        }

        deinit {
            #if DEBUG
                log.verbose("START DEINIT")
                defer { log.verbose("END DEINIT") }
            #endif
            libssh2_sftp_close_handle(sftpHandle)
        }

        func read() -> ReadWriteProcessor.ReadResult {
            let result = libssh2_sftp_read(sftpHandle, &buffer, SFTPHandle.bufferSize)
            return ReadWriteProcessor.processRead(result: result, buffer: &buffer, session: cSession)
        }

        func write(_ data: Data) -> ReadWriteProcessor.WriteResult {
            let result: Result<Int, SSHError> = data.withUnsafeBytes {
                guard let unsafePointer = $0.bindMemory(to: Int8.self).baseAddress else {
                    return .failure(SSHError.genericError("SFTP write failed to bind memory"))
                }
                return .success(libssh2_sftp_write(sftpHandle, unsafePointer, data.count))
            }
            switch result {
            case let .failure(error):
                return .error(error)
            case let .success(value):
                return ReadWriteProcessor.processWrite(result: value, session: cSession)
            }
        }

        func readDir(_ attrs: inout LIBSSH2_SFTP_ATTRIBUTES) -> ReadWriteProcessor.ReadResult {
            let result = libssh2_sftp_readdir_ex(sftpHandle, &buffer, SFTPHandle.bufferSize, nil, 0, &attrs)
            return ReadWriteProcessor.processRead(result: Int(result), buffer: &buffer, session: cSession)
        }

        // Recommended buffer size accordingly to the docs:
        // https://www.libssh2.org/libssh2_sftp_write.html
        fileprivate static let bufferSize = 32768

        private let cSession: OpaquePointer
        private let sftpHandle: OpaquePointer
        private var buffer = [Int8](repeating: 0, count: SFTPHandle.bufferSize)
    }

    private let cSession: OpaquePointer
    private let sftpSession: OpaquePointer

    // Retain session to ensure it is not freed before the sftp session is closed
    private let session: Session

    private func handleSFTPCommandResult(_ result: Int32) throws {
        let processedResult = ReadWriteProcessor.processWrite(result: Int(result), session: cSession)
        switch processedResult {
        case .written:
            break
        case .eagain:
            break
        case let .error(error):
            throw error
        }
    }
}
