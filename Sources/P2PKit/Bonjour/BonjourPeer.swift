//
//  BonjourPeer.swift
//  P2PChat
//
//  Created by Henrik Panhans on 22.03.25.
//

import Foundation
import Network

public struct BonjourPeer: Peer {

    // MARK: - Properties

    public let endpoint: NWEndpoint

    public var id: ID {
        switch endpoint {
        case let .hostPort(host, port):
            "\(host):\(port)"
        case let .service(name, type, domain, interface):
            ["\(name).\(type).\(domain)", interface?.name].compactMap { $0 }.joined(separator: ".")
        case let .unix(path):
            path
        case let .url(url):
            url.absoluteString
        case let .opaque(path):
            path.debugDescription ?? path.description
        @unknown default:
            UUID().uuidString
        }
    }

    // MARK: - Init

    public init(endpoint: NWEndpoint) {
        self.endpoint = endpoint
    }

}
