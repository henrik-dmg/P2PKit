//
//  BonjourAsyncDataTransferService.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.07.25.
//

import Foundation
import Logging
import Network

@available(iOS 26, macOS 26, *)
@Observable
public class BonjourAsyncDataTransferService: NSObject, PeerDataTransferService {

    // MARK: - Nested Types

    public typealias P = BonjourPeer
    public typealias S = BonjourService

    typealias ConnectionProtocol = TLV
    typealias Connection = NetworkConnection<ConnectionProtocol>

    enum SendError: LocalizedError {
        case noConnectionToPeer(ID)
    }

    // MARK: - Properties

    public let ownPeerID: ID
    public var connectedPeers: [ID] {
        Array(connections.keys)
    }

    public let service: S
    public weak var delegate: PeerDataTransferServiceDelegate?

    private var connections: [ID: Connection] = [:]
    private var receiveTasks: [ID: Task<Void, Error>] = [:]

    private let logger = Logger.bonjour("datatransfer-async")
    private let byteCountFormatter = ByteCountFormatter.default

    // MARK: - Init

    public init(ownPeerID: ID, service: S) {
        self.ownPeerID = ownPeerID
        self.service = service
        super.init()
    }

    // MARK: - PeerDataTransferService

    public func connect(to peer: BonjourPeer) {
        let peerID = peer.id
        let connection = NetworkConnection(to: peer.endpoint) {
            TLV()
        }
        connect(to: peerID, using: connection)
    }

    func connect(to peerID: ID, using connection: Connection) {
        guard connections[peerID] == nil else {
            logger.error("Already has connection to \(peerID)")
            return
        }

        configureConnection(connection, for: peerID)
        connections[peerID] = connection
    }

    public func send(_ data: Data, to peerID: String) async throws {
        guard let connection = connections[peerID] else {
            return
        }
        try await connection.send(data, type: 0)
    }

    public func disconnect(from peerID: ID) {
        connections[peerID] = nil
        logger.debug("Cleaned up connection to \(peerID)")
    }

    public func disconnectAll() {
        let ids = connections.keys
        for id in ids {
            disconnect(from: id)
        }
    }

    // MARK: - Helpers

    func configureConnection(_ connection: Connection, for peerID: ID) {
        connection.onStateUpdate { [weak self] connection, newState in
            guard let self else {
                return
            }
            switch newState {
            case .setup:
                logger.info("Connection to \(peerID) setting up")
            case let .waiting(error):
                logger.error("Connection to \(peerID) waiting: \(error)")
            case .preparing:
                logger.info("Connection to \(peerID) preparing")
            case .ready:
                logger.info("Connection to \(peerID) ready, starting receive")
                delegate?.serviceDidConnectToPeer(with: peerID)
                receive(from: peerID)
            case let .failed(error):
                logger.error("Connection to \(peerID) failed: \(error)")
                delegate?.serviceDidFailToConnectToPeer(with: peerID, error: error)
                disconnect(from: peerID)
            case .cancelled:
                logger.info("Connection to \(peerID) was stopped")
                delegate?.serviceDidDisconnectFromPeer(with: peerID)
                disconnect(from: peerID)
            @unknown default:
                logger.warning("Unknown connection state: \(String(describing: newState))")
            }
        }

        connection.onPathUpdate { [weak self] connection, newPath in
            guard let self else {
                return
            }

            let usedInterfaces = newPath.availableInterfaces
                .filter { newPath.usesInterfaceType($0.type) }
                .map { $0.name }
                .joined(separator: ",")

            switch newPath.status {
            case .satisfied:
                logger.debug("Path for \(peerID) is satisfied", metadata: ["interfaces": .string(usedInterfaces)])
            case .unsatisfied:
                logger.debug("Path for \(peerID) is unsatisfied", metadata: ["interfaces": .string(usedInterfaces)])
            case .requiresConnection:
                logger.debug("Path for \(peerID) requires connection", metadata: ["interfaces": .string(usedInterfaces)])
            @unknown default:
                logger.warning("Unknown path status for \(peerID): \(String(describing: newPath.status))")
            }
        }
    }

    // Receives messages continuously from a given connection
    private func receive(from peerID: ID) {
        guard receiveTasks[peerID] == nil, let connection = connections[peerID] else {
            return
        }
        receiveTasks[peerID] = Task { [weak self] in
            do {
                let (data, metadata) = try await connection.receive()
                try self?.handleDataReceived(from: peerID, data: data, metadata: metadata)
            } catch {
                self?.logger.error("Error receiving data: \(error)")
            }
        }
    }

    private func handleDataReceived(from peerID: ID, data: Data, metadata: ConnectionProtocol.Metadata) throws {
        receiveTasks[peerID] = nil

        guard metadata.type == 0 else {
            logger.critical("Peer \(peerID) send message type other than 0. Peer might be compromised")
            disconnect(from: peerID)
            return
        }

        // Check if data was received
        if !data.isEmpty {
            logger.info("Received \(byteCountFormatter.string(fromByteCount: Int64(data.count))) from \(peerID)")
            delegate?.serviceReceived(data: data, from: peerID)
        }

        // Check for errors or connection end
        if metadata.isComplete {
            logger.info("Receive from \(peerID) complete")
            disconnect(from: peerID)
        } else {
            // If no error and not complete, continue receiving
            receive(from: peerID)
        }
    }

}
