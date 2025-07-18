//
//  BonjourDataTransferService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 23.03.25.
//

import Foundation
import Logging
import Network

@Observable
public class BonjourDataTransferService: NSObject, PeerDataTransferService {

    // MARK: - Nested Types

    public typealias P = BonjourPeer
    public typealias S = BonjourService

    enum SendError: LocalizedError {
        case noConnectionToPeer(P.ID)
    }

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

    private let chunkReceiver: DataChunkReceiver
    private let logger = Logger.bonjour("datatransfer")
    private let byteCountFormatter = ByteCountFormatter.default

    // MARK: - Init

    public init(ownPeerID: ID, service: S, endOfMessageSingal: Data) {
        self.ownPeerID = ownPeerID
        self.service = service
        chunkReceiver = DataChunkReceiver(endOfMessageSignal: endOfMessageSingal)
        super.init()
    }

    // MARK: - PeerDataTransferService

    public func connect(to peer: BonjourPeer) {
        let connection = NWConnection(to: peer.endpoint, using: .applicationService)
        connect(with: connection, peerID: peer.id)
    }

    func connect(with connection: NWConnection, peerID: P.ID) {
        guard connections[peerID] == nil else {
            logger.error("Already has connection to \(peerID)")
            return
        }
        connection.stateUpdateHandler = { [weak self] newState in
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
                receive(on: connection, peerID: peerID)
            case let .failed(error):
                logger.error("Connection to \(peerID) failed: \(error)")
                delegate?.serviceDidFailToConnectToPeer(with: peerID, error: error)
                cleanUpConnection(for: peerID)
            case .cancelled:
                logger.info("Connection to \(peerID) was stopped")
                delegate?.serviceDidDisconnectFromPeer(with: peerID)
                cleanUpConnection(for: peerID)
            @unknown default:
                logger.warning("Unknown connection state: \(String(describing: newState))")
            }
        }
        connection.pathUpdateHandler = { [weak self] newPath in
            guard let self else {
                return
            }

            let usedInterfaces = newPath.availableInterfaces.filter { newPath.usesInterfaceType($0.type) }.map { $0.name }.joined(separator: ",")

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
        connection.start(queue: connectionsQueue)
        connections[peerID] = connection
    }

    public func send(_ data: Data, to peerID: String) async throws {
        guard let connection = connections[peerID] else {
            logger.error("No stored connection for \(peerID)")
            throw SendError.noConnectionToPeer(peerID)
        }
        // Send the data followed by the end of message signal.
        var completeData = data
        completeData.append(chunkReceiver.endOfMessageSignal)

        let formattedDataSize = byteCountFormatter.string(fromByteCount: Int64(completeData.count))
        logger.info("Sending \(formattedDataSize) to peer \(peerID)")
        try await connection.sendData(completeData)
        logger.info("Successfully sent \(formattedDataSize) to peer \(peerID)")
    }

    public func disconnect(from peerID: P.ID) {
        guard let connection = connections[peerID] else {
            logger.warning("No connection to \(peerID) to cancel")
            return
        }
        logger.debug("Cancelling connection to \(peerID)")
        connection.cancel()
    }

    public func disconnectAll() {
        let ids = connections.keys
        for id in ids {
            disconnect(from: id)
        }
    }

    // MARK: - Helpers

    // Receives messages continuously from a given connection
    private func receive(on connection: NWConnection, peerID: P.ID) {
        guard connectedPeers.contains(peerID) else {
            logger.warning("Stopping receive for disconnected peer \(peerID)")
            return
        }

        // Receive 64KB in a single completion
        // Since we can dispatch all data at once (compared to CoreBluetooth),
        // we can hardcode max length because we don't need to sync with the size of chunks that are sent.
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            guard let self else {
                return
            }

            // Check if data was received
            if let data, !data.isEmpty {
                logger.trace("Received \(byteCountFormatter.string(fromByteCount: Int64(data.count))) (partial) from \(peerID)")

                if chunkReceiver.receive(data, from: peerID), let completeData = chunkReceiver.allReceivedData(from: peerID) {
                    logger.info("Received \(byteCountFormatter.string(fromByteCount: Int64(completeData.count))) from \(peerID)")
                    delegate?.serviceReceived(data: completeData, from: peerID)
                }
            }

            // Check for errors or connection end
            if isComplete {
                logger.info("Receive from \(peerID) complete")
                disconnect(from: peerID)
            } else if let error {
                logger.error("Receive error: \(error)")
                disconnect(from: peerID)
            } else {
                // If no error and not complete, continue receiving
                receive(on: connection, peerID: peerID)
            }
        }
    }

    private func cleanUpConnection(for peerID: P.ID) {
        connections[peerID] = nil
        chunkReceiver.wipeReceivedData(from: peerID)
        logger.debug("Cleaned up connection to \(peerID)")
    }

}
