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

    // MARK: - Init

    public var id: ID {
        identifier.displayName
    }

}
