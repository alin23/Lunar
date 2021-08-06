//
//  FileType.swift
//
//
//  Created by Kyle Ishie on 12/10/19.
//

import Foundation
// import CSSH

public enum FileType {
    case link
    case regularFile
    case directory
    case characterSpecialFile
    case blockSpecialFile
    case fifo
    case socket

    // MARK: Lifecycle

    public init?(rawValue: Int32) {
        switch rawValue & LIBSSH2_SFTP_S_IFMT {
        case LIBSSH2_SFTP_S_IFLNK:
            self = .link
        case LIBSSH2_SFTP_S_IFREG:
            self = .regularFile
        case LIBSSH2_SFTP_S_IFDIR:
            self = .directory
        case LIBSSH2_SFTP_S_IFCHR:
            self = .characterSpecialFile
        case LIBSSH2_SFTP_S_IFBLK:
            self = .blockSpecialFile
        case LIBSSH2_SFTP_S_IFIFO:
            self = .fifo
        case LIBSSH2_SFTP_S_IFSOCK:
            self = .socket
        default:
            return nil
        }
    }
}
