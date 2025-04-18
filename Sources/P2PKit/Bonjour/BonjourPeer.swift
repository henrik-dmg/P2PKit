//
//  BonjourPeer.swift
//  P2PChat
//
//  Created by Henrik Panhans on 22.03.25.
//

import Foundation
import Network

public struct BonjourPeer: Peer {

    // MARK: - Nested Types

    struct ServiceConfiguration {
        let name: String
        let type: String
        let domain: String
        let interface: NWInterface?
    }

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

    var serviceConfiguration: ServiceConfiguration? {
        if case let .service(name, type, domain, interface) = endpoint {
            return .init(name: name, type: type, domain: domain, interface: interface)
        } else {
            return nil
        }
    }

}

// MARK: - Preview Helpers

extension BonjourPeer {

    public static func preview() -> Self {
        BonjourPeer(endpoint: .service(name: "P2P Chat Service", type: "_p2p._tcp", domain: "local.", interface: nil))
    }

}
