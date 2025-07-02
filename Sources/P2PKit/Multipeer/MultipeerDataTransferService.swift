//
//  MultipeerDataTransferService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 23.03.25.
//

import Foundation
import Logging
import MultipeerConnectivity
import Observation

@Observable
public class MultipeerDataTransferService: NSObject, PeerDataTransferService {

    // MARK: - Nested Types

    public typealias P = MultipeerPeer
    public typealias S = MultipeerService

    // MARK: - Properties

    public let ownPeerID: ID
    public var connectedPeers: [ID] {
        Array(connections.keys)
    }

    public let service: S
    public weak var delegate: PeerDataTransferServiceDelegate?

    private var connections: [ID: MCPeerID] = [:]
    @ObservationIgnored
    lazy var session = makeSession()
    @ObservationIgnored
    lazy var ownMCPeerID = MCPeerID(displayName: ownPeerID)

    private let logger = Logger.multipeer("datatransfer")

    // MARK: - Init

    public init(ownPeerID: ID, service: S) {
        self.ownPeerID = ownPeerID
        self.service = service
        super.init()

    }

    // MARK: - PeerDataTransferService

    public func connect(to peer: P) {
        session.nearbyConnectionData(forPeer: peer.identifier) { [weak self] data, error in
            if let error {
                self?.logger.error("Error fetching nearby connection data for peer \(peer.identifier): \(error)")
                return
            }
            guard let data else {
                self?.logger.error("No error but no data either")
                return
            }
            self?.session.connectPeer(peer.identifier, withNearbyConnectionData: data)
        }
    }

    public func send(_ data: Data, to peerID: ID) async throws {
        guard let storedPeerID = connections[peerID] else {
            logger.warning("No stored peerID for \(peerID)")
            return
        }
        guard session.connectedPeers.contains(storedPeerID) else {
            logger.warning("Stored peer \(storedPeerID) not connected")
            return
        }
        try session.send(data, toPeers: [storedPeerID], with: .reliable)
        logger.info("Successfully sent data to peer \(peerID)")
    }

    public func disconnect(from peerID: ID) {
        session.disconnect()  // Apparently not possible to disconnect from single peer
    }

    public func disconnectAll() {
        session.disconnect()
    }

    // MARK: - Helpers

    private func makeSession() -> MCSession {
        let session = MCSession(peer: ownMCPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        return session
    }

}

// MARK: - MCSessionDelegate

extension MultipeerDataTransferService: MCSessionDelegate {

    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .notConnected:
            connections[peerID.displayName] = nil
            delegate?.serviceDidDisconnectFromPeer(with: peerID.displayName)
            logger.info("Peer \(peerID.displayName) disconnected")
        case .connecting:
            logger.info("Peer \(peerID.displayName) connecting")
        case .connected:
            connections[peerID.displayName] = peerID
            delegate?.serviceDidConnectToPeer(with: peerID.displayName)
            logger.info("Peer \(peerID.displayName) connected")
        @unknown default:
            logger.warning("Unknown connection state: \(String(describing: state))")
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        delegate?.serviceReceived(data: data, from: peerID.displayName)
        logger.info("Received data from \(peerID.displayName)")
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        logger.info("Session did receive stream with name \(streamName)")
    }

    public func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {
        logger.info("Session did receiving resource with name \(resourceName)")
    }

    public func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: (any Error)?
    ) {
        logger.info("Session did finish receiving resource with name \(resourceName)")
    }

}
