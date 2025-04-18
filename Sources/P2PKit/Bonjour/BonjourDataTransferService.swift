//
//  BonjourDataTransferService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 23.03.25.
//

import Foundation
import Network
import OSLog
import Observation

@Observable
public class BonjourDataTransferService: NSObject, PeerDataTransferService {

    // MARK: - Nested Types

    public typealias P = BonjourPeer
    public typealias S = BonjourService

    // MARK: - Properties

    public let ownPeerID: ID
    public var connectedPeers: [ID] {
        Array(connections.keys)
    }

    public let service: S
    public weak var delegate: PeerDataTransferServiceDelegate?

    private var connections: [ID: NWConnection] = [:]
    @ObservationIgnored
    private let connectionsQueue = DispatchQueue(label: "connectionsQueue")

    private let logger = Logger.bonjour("datatransfer")

    // MARK: - Init

    public init(ownPeerID: ID, service: S) {
        self.ownPeerID = ownPeerID
        self.service = service
        super.init()
    }

    // MARK: - PeerDataTransferService

    public func connect(to peer: BonjourPeer) {
        let connection = NWConnection(to: peer.endpoint, using: .tcp)
        connect(with: connection, peerID: peer.id)
    }

    func connect(with connection: NWConnection, peerID: P.ID) {
        guard connections[peerID] == nil else {
            return  // Already connected to peer
        }
        connection.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }
            switch newState {
            case .setup:
                logger.info("Connection setting up")
            case let .waiting(error):
                logger.error("Connection waiting: \(error)")
            case .preparing:
                logger.info("Connection preparing")
            case .ready:
                logger.info("Connection ready, starting receive")
                delegate?.serviceDidConnectToPeer(with: peerID)
                receive(on: connection, peerID: peerID)
            case let .failed(error):
                logger.error("Connection failed: \(error)")
                delegate?.serviceDidFailToConnectToPeer(with: peerID, error: error)
                disconnect(from: peerID)
            case .cancelled:
                logger.info("Connection was stopped")
                delegate?.serviceDidDisconnectFromPeer(with: peerID)
                disconnect(from: peerID)
            @unknown default:
                logger.warning("Unknown connection state: \(String(describing: newState))")
            }
        }
        connection.start(queue: connectionsQueue)
        connections[peerID] = connection
    }

    public func send(_ data: Data, to peerID: String) async throws {
        guard let connection = connections[peerID] else {
            return
        }
        try await connection.sendData(data)
    }

    public func disconnect(from peerID: P.ID) {
        guard let connection = connections[peerID] else {
            logger.error("No connection to \(peerID) to cancel")
            return
        }
        connection.cancel()
        connections[peerID] = nil
    }

    public func disconnectAll() {
        let ids = connections.keys
        for id in ids {
            disconnect(from: id)
        }
    }

    // MARK: - Helpers

    // Receives messages continuously from a given connection
    func receive(on connection: NWConnection, peerID: P.ID) {
        guard connectedPeers.contains(peerID) else {
            logger.warning("Stopping receive for disconnected peer \(peerID)")
            return
        }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            // Check if data was received
            if let data, !data.isEmpty {
                self?.logger.debug("Received \(data.count) bytes from \(peerID)")
                self?.delegate?.serviceReceived(data: data, from: peerID)
            }

            // Check for errors or connection end
            if isComplete {
                self?.logger.info("Receive complete")
                connection.cancel()
            } else if let error {
                self?.logger.error("Receive error: \(error)")
                connection.cancel()
            } else {
                // If no error and not complete, continue receiving
                self?.receive(on: connection, peerID: peerID)
            }
        }
    }

}
