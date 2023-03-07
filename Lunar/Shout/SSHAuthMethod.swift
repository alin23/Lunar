//
//  SSHAuthMethod.swift
//  Shout
//
//  Created by Jake Heiser on 3/4/18.
//

import Foundation

// MARK: - SSHAuthMethod

protocol SSHAuthMethod {
    func authenticate(ssh: SSH, username: String) throws
}

// MARK: - SSHPassword

/// Password-based authentication method
struct SSHPassword: SSHAuthMethod {
    /// Creates a new password-based authentication using the given password
    ///
    /// - Parameter password: the password to authenticate with
    init(_ password: String) {
        self.password = password
    }

    let password: String

    func authenticate(ssh: SSH, username: String) throws {
        try ssh.session.authenticate(username: username, password: password)
    }

}

// MARK: - SSHAgent

/// Agent-based authentication method
struct SSHAgent: SSHAuthMethod {
    /// Creates a new agent-based authentication
    init() {}

    func authenticate(ssh: SSH, username: String) throws {
        let agent = try ssh.session.openAgent()
        try agent.connect()
        try agent.listIdentities()

        var last: Agent.PublicKey?
        var success = false
        while let identity = try agent.getIdentity(last: last) {
            if agent.authenticate(username: username, key: identity) {
                success = true
                break
            }
            last = identity
        }
        guard success else {
            throw SSHError.genericError("failed to authenticate using the agent")
        }
    }
}

// MARK: - SSHKey

/// Key-based authentication method
struct SSHKey: SSHAuthMethod {
    /// Creates a new key-based authentication
    ///
    /// - Parameters:
    ///   - privateKey: the path to the private key
    ///   - publicKey: the path to the key; defaults to private key path + ".pub"
    ///   - passphrase: the passphrase encrypting the key; defaults to nil
    init(privateKey: String, publicKey: String? = nil, passphrase: String? = nil) {
        self.privateKey = NSString(string: privateKey).expandingTildeInPath
        if let publicKey {
            self.publicKey = NSString(string: publicKey).expandingTildeInPath
        } else {
            self.publicKey = self.privateKey + ".pub"
        }
        self.passphrase = passphrase
    }

    let privateKey: String
    let publicKey: String
    let passphrase: String?

    func authenticate(ssh: SSH, username: String) throws {
        // If programatically given a passphrase, use it
        if let passphrase {
            try ssh.session.authenticate(
                username: username,
                privateKey: privateKey,
                publicKey: publicKey,
                passphrase: passphrase
            )
            return
        }

        // Otherwise, try logging in without any passphrase
        do {
            try ssh.session.authenticate(
                username: username,
                privateKey: privateKey,
                publicKey: publicKey,
                passphrase: nil
            )
            return
        } catch {}

        // If that doesn't work, try using the Agent in case the passphrase has been saved there
        do {
            try SSHAgent().authenticate(ssh: ssh, username: username)
            return
        } catch {}

        // Finally, as a fallback, ask for the passphrase
        let enteredPassphrase = String(cString: getpass("Enter passphrase for \(privateKey) (empty for no passphrase):"))
        try ssh.session.authenticate(
            username: username,
            privateKey: privateKey,
            publicKey: publicKey,
            passphrase: enteredPassphrase
        )
    }
}
