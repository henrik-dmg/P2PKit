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

    enum SendError: LocalizedError {
        case peerIDNotFound(P.ID)
        case peerNotConnected(P.ID)
    }

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
    private let byteCountFormatter = ByteCountFormatter.default

    // MARK: - Init

    public init(ownPeerID: ID, service: S) {
        self.ownPeerID = ownPeerID
        self.service = service
        super.init()

    }

    // MARK: - PeerDataTransferService

    public func connect(to peer: P) {
        logger.info("Connecting to peer \(peer.identifier)")
        session.nearbyConnectionData(forPeer: peer.identifier) { [weak self] data, error in
            if let error {
                self?.logger.error("Couldn't fetch nearby connection data for peer \(peer.identifier): \(error)")
                return
            }
            guard let data else {
                self?.logger.error("No error but no data either, this is an API bug")
                return
            }
            self?.session.connectPeer(peer.identifier, withNearbyConnectionData: data)
        }
    }

    public func send(_ data: Data, to peerID: ID) async throws {
        guard let storedPeerID = connections[peerID] else {
            logger.error("No stored peerID for \(peerID)")
            throw SendError.peerIDNotFound(peerID)
        }
        guard session.connectedPeers.contains(storedPeerID) else {
            logger.error("Stored peer \(storedPeerID) not connected")
            connections[peerID] = nil
            throw SendError.peerNotConnected(peerID)
        }
        let formattedDataSize = byteCountFormatter.string(fromByteCount: Int64(data.count))
        logger.info("Sending \(formattedDataSize) to peer \(peerID)")
        try session.send(data, toPeers: [storedPeerID], with: .reliable)
        logger.info("Successfully sent \(formattedDataSize) to peer \(peerID)")
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

    func peerID(for mcPeerID: MCPeerID) -> P.ID {
        MultipeerPeer(identifier: mcPeerID, info: nil).id
    }

}

// MARK: - MCSessionDelegate

extension MultipeerDataTransferService: MCSessionDelegate {

    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .notConnected:
            logger.info("Peer \(peerID.displayName) disconnected")
            connections[peerID.displayName] = nil
            delegate?.serviceDidDisconnectFromPeer(with: peerID.displayName)
        case .connecting:
            logger.info("Peer \(peerID.displayName) connecting")
        case .connected:
            logger.info("Peer \(peerID.displayName) connected")
            connections[peerID.displayName] = peerID
            delegate?.serviceDidConnectToPeer(with: peerID.displayName)
        @unknown default:
            logger.warning("Unknown connection state: \(String(describing: state))")
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        logger.info("Received \(byteCountFormatter.string(fromByteCount: Int64(data.count))) from \(peerID.displayName)")
        delegate?.serviceReceived(data: data, from: peerID.displayName)
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        logger.info("Session did receive stream with name \(streamName) from \(peerID.displayName)")
    }

    public func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {
        logger.info("Session did start receiving resource with name \(resourceName) from \(peerID.displayName)")
    }

    public func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: (any Error)?
    ) {
        logger.info("Session did finish receiving resource with name \(resourceName) from \(peerID.displayName)")
    }

}
