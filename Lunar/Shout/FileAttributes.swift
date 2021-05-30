//
//  FileAttributes.swift
//
//
//  Created by Kyle Ishie on 12/10/19.
//

import Foundation
// import CSSH

public struct FileAttributes {
    public let fileType: FileType

    public let size: UInt64

    public let userId: UInt

    public let groupId: UInt

    public let permissions: FilePermissions

    public let lastAccessed: Date

    public let lastModified: Date

    init?(attributes: LIBSSH2_SFTP_ATTRIBUTES) {
        guard let fileType = FileType(rawValue: Int32(attributes.permissions)) else { return nil }
        self.fileType = fileType
        size = attributes.filesize
        userId = attributes.uid
        groupId = attributes.gid
        permissions = FilePermissions(rawValue: Int32(attributes.permissions))
        lastAccessed = Date(timeIntervalSince1970: Double(attributes.atime))
        lastModified = Date(timeIntervalSince1970: Double(attributes.mtime))
    }
}
