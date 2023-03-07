//
//  Agent.swift
//  Shout
//
//  Created by Jake Heiser on 3/4/18.
//

// import CSSH

/// Direct bindings to libssh2_agent
final class Agent {
    init(cSession: OpaquePointer) throws {
        guard let cAgent = libssh2_agent_init(cSession) else {
            throw SSHError.mostRecentError(session: cSession, backupMessage: "libssh2_agent_init failed")
        }
        self.cSession = cSession
        self.cAgent = cAgent
    }

    deinit {
        #if DEBUG
            log.verbose("START DEINIT")
            defer { log.verbose("END DEINIT") }
        #endif
        libssh2_agent_disconnect(cAgent)
        libssh2_agent_free(cAgent)
    }

    final class PublicKey: CustomStringConvertible {
        init(cIdentity: UnsafeMutablePointer<libssh2_agent_publickey>) {
            self.cIdentity = cIdentity
        }

        var description: String {
            "Public key: " + String(cString: cIdentity.pointee.comment)
        }

        fileprivate let cIdentity: UnsafeMutablePointer<libssh2_agent_publickey>
    }

    func connect() throws {
        let code = libssh2_agent_connect(cAgent)
        try SSHError.check(code: code, session: cSession)
    }

    func listIdentities() throws {
        let code = libssh2_agent_list_identities(cAgent)
        try SSHError.check(code: code, session: cSession)
    }

    func getIdentity(last: PublicKey?) throws -> PublicKey? {
        var publicKeyOptional: UnsafeMutablePointer<libssh2_agent_publickey>?
        let code = libssh2_agent_get_identity(cAgent, &publicKeyOptional, last?.cIdentity)

        if code == 1 { // No more identities
            return nil
        }

        try SSHError.check(code: code, session: cSession)

        guard let publicKey = publicKeyOptional else {
            throw SSHError.genericError("libssh2_agent_get_identity failed")
        }

        return PublicKey(cIdentity: publicKey)
    }

    func authenticate(username: String, key: PublicKey) -> Bool {
        let code = libssh2_agent_userauth(cAgent, username, key.cIdentity)
        return code == 0
    }

    private let cSession: OpaquePointer
    private let cAgent: OpaquePointer
}
