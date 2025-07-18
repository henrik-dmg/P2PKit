//
//  MultipeerPeer.swift
//  P2PChat
//
//  Created by Henrik Panhans on 23.03.25.
//

import MultipeerConnectivity

public struct MultipeerPeer: Peer {

    // MARK: - Properties

    public let identifier: MCPeerID
    public let info: [String: String]?

    public var id: ID {
        identifier.displayName // This is not ideal as people can set the same name
    }

    // MARK: - Init

    public init(identifier: MCPeerID, info: [String: String]?) {
        self.identifier = identifier
        self.info = info
    }

}
