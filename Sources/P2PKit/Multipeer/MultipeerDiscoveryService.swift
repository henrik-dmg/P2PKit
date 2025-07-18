//
//  MultipeerDiscoveryService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 23.03.25.
//

import Logging
import MultipeerConnectivity
import Observation

@Observable
public final class MultipeerDiscoveryService: MultipeerDataTransferService, PeerDiscoveryService {

    // MARK: - Properties

    public private(set) var state: ServiceState = .inactive

    public var availablePeers: [P] {
        Array(discoveredPeers.values)
    }

    private var discoveredPeers: [ID: P] = [:]
    @ObservationIgnored
    private lazy var browser = makeBrowser()

    private let logger = Logger.multipeer("discovery")

    // MARK: - PeerDiscoveryService

    public func startDiscoveringPeers() {
        browser.startBrowsingForPeers()
        logger.info("Browser started")
        state = .active
    }

    public func stopDiscoveringPeers() {
        browser.stopBrowsingForPeers()
        logger.info("Browser stopped")
        discoveredPeers.removeAll()
        state = .inactive
    }

    // MARK: - Overridden Methods

    public override func connect(to peer: P) {
        logger.info("Inviting \(peer.identifier) to session")
        browser.invitePeer(peer.identifier, to: session, withContext: nil, timeout: 10)
    }

    // MARK: - Helpers

    private func makeBrowser() -> MCNearbyServiceBrowser {
        let browser = MCNearbyServiceBrowser(peer: session.myPeerID, serviceType: service.type)
        browser.delegate = self
        return browser
    }

}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerDiscoveryService: MCNearbyServiceBrowserDelegate {

    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let mappedInfo = (info ?? [:]).mapValues {
            Logger.MetadataValue.string($0)
        }
        logger.info(
            "Browser found peer \(peerID.displayName)",
            metadata: ["discovery-info": .dictionary(mappedInfo)]
        )
        discoveredPeers[peerID.displayName] = MultipeerPeer(identifier: peerID, info: info)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger.info("Browser lost peer \(peerID.displayName)")
        discoveredPeers[peerID.displayName] = nil
    }

    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: any Error) {
        logger.error("Browser did not start browsing for peers: \(error)")
        state = .error(error)
    }

}
