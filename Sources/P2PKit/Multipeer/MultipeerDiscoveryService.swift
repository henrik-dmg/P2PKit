//
//  MultipeerDiscoveryService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 23.03.25.
//

import MultipeerConnectivity
import OSLog
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
        state = .active
    }

    public func stopDiscoveringPeers() {
        browser.stopBrowsingForPeers()
        discoveredPeers.removeAll()
        state = .inactive
    }

    // MARK: - Overridden Methods

    public override func connect(to peer: P) {
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
        logger.info("Browser found peer \(peerID.displayName)")
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
