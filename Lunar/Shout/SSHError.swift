//
//  SSHError.swift
//  Shout
//
//  Created by Jake Heiser on 3/6/18.
//

// import CSSH

public struct SSHError: Swift.Error, CustomStringConvertible {
    // MARK: Lifecycle

    private init(kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }

    private init(kind: Kind, session: OpaquePointer, backupMessage: String = "") {
        var messagePointer: UnsafeMutablePointer<Int8>?
        var length: Int32 = 0

        libssh2_session_last_error(session, &messagePointer, &length, 0)
        let message = messagePointer.flatMap { String(cString: $0) } ?? backupMessage

        self.init(kind: kind, message: message)
    }

    // MARK: Public

    public enum Kind: Int32 {
        case genericError = 1
        case bannerRecv
        case bannerSend
        case invalidMac
        case kexFailure // 5
        case alloc
        case socketSend
        case keyExchangeFailure
        case errorTimeout
        case hostkeyInit // 10
        case hostkeySign
        case decrypt
        case socketDisconnect
        case proto
        case passwordExpired // 15
        case file
        case methodNone
        case authenticationFailed
        case publicKeyUnverified
        case channelOutOfOrder // 20
        case channelFailure
        case channelRequestDenied
        case channelUnknown
        case channelWindowExceeded
        case channelPacketExceeded // 25
        case channelClosed
        case channelEofSent
        case scpProtocol
        case zlib
        case socketTimeout // 30
        case sftpProtocol
        case requestDenied
        case methodNotSupported
        case inval
        case invalidPollType // 35
        case publicKeyProtocol
        case eagain
        case bufferTooSmall
        case badUse
        case compress // 40
        case outOfBoundary
        case agentProtocol
        case socketRecv
        case encrypt
        case badSocket // 45
        case knownHosts
        case channelWindowFull
        case keyfileAuthFailed
    }

    public let kind: Kind
    public let message: String

    public var description: String {
        let kindMessage = "code \(kind.rawValue) = " + String(describing: kind)
        if message.isEmpty {
            return "Error: \(kindMessage)"
        }
        return "Error: \(message) (\(kindMessage))"
    }

    // MARK: Internal

    static func check(code: Int32, session: OpaquePointer) throws {
        if code != 0 {
            throw SSHError.codeError(code: code, session: session)
        }
    }

    static func codeError(code: Int32, session: OpaquePointer) -> SSHError {
        SSHError(kind: Kind(rawValue: -code) ?? .genericError, session: session)
    }

    static func genericError(_ message: String) -> SSHError {
        SSHError(kind: .genericError, message: message)
    }

    static func mostRecentError(session: OpaquePointer, backupMessage: String = "") -> SSHError {
        let kind = Kind(rawValue: libssh2_session_last_errno(session)) ?? .genericError
        return SSHError(kind: kind, session: session, backupMessage: backupMessage)
    }
}
