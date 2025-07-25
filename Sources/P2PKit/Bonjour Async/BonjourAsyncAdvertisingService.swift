//
//  BonjourAsyncAdvertisingService.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.07.25.
//

import Foundation
import Logging
import Network

@available(iOS 26, macOS 26, *)
@Observable
public final class BonjourAsyncAdvertisingService: BonjourAsyncDataTransferService, PeerAdvertisingService {

    // MARK: - Properties

    public private(set) var state: ServiceState = .inactive
    public weak var advertisingDelegate: (any PeerAdvertisingServiceDelegate<S>)?

    @ObservationIgnored
    private var listener: NetworkListener<ConnectionProtocol>?
    @ObservationIgnored
    private var listenerTask: Task<Void, Never>?

    private let logger = Logger.bonjour("advertising-async")

    // MARK: - PeerDiscoveryService

    public func startAdvertisingService() {
        guard listener == nil else {
            logger.error("Tried to start advertising service multiple times")
            return
        }

        do {
            let listener = try makeListener()
            startListener(listener)
        } catch {
            state = .error(error)
        }
    }

    public func stopAdvertisingService() {
        listenerTask?.cancel()
    }

    // MARK: - Helpers

    private func startListener(_ listener: NetworkListener<ConnectionProtocol>) {
        self.listener = listener
        listenerTask = Task { [weak self] in
            do {
                try await listener.run { [weak self] connection in
                    try await self?.handleNewConnection(connection)
                }
                self?.logger.info("Listener finished")
                self?.updateState(.inactive)
                self?.disconnectAll()
            } catch {
                self?.logger.error("Error running listener: \(error)")
            }
        }
    }

    private func handleNewConnection(_ connection: Connection) async throws {
        let peer = BonjourPeer(endpoint: connection.remoteEndpoint)
//        logger.info("New connection \(connection.debugDescription)")
//        let peer = BonjourPeer(endpoint: connection.endpoint)
//        connect(with: connection, peerID: peer.id)
        connect(to: peer.id, using: connection)

        for try await message in connection.messages {
            print(message.content)
        }
    }

    private func makeListener() throws -> NetworkListener<ConnectionProtocol> {
        let bonjourProvider = BonjourListenerProvider(name: ownPeerID, type: service.type)

        let parameters = NWParameters.applicationService
        parameters.includePeerToPeer = false  // Allow discovery on AWDL, etc.
        let listener = try NetworkListener(for: bonjourProvider, using: .parameters(initialParameters: parameters) {
            ConnectionProtocol()
        })

        listener.onServiceRegistrationUpdate { [weak self] listener, registrationState in
            switch registrationState {
            case .add:
                self?.logger.info("Service added")
                self?.updateState(.active)
            case .remove:
                self?.logger.info("Service removed")
            @unknown default:
                self?.logger.warning(
                    "Unknown service registration state: \(String(describing: registrationState))")
            }
        }

        listener.onStateUpdate { [weak self] listener, newState in
            switch newState {
            case .setup:
                self?.logger.info("Listener setting up")
            case let .waiting(error):
                self?.logger.error("Listener waiting with error: \(error)")
            case .ready:
                self?.logger.info("Listener ready")
            case let .failed(error):
                self?.logger.error("Listener error: \(error)")
                self?.updateState(.error(error))
                self?.disconnectAll()
            case .cancelled:
                self?.logger.info("Listener stopped")
            @unknown default:
                self?.logger.warning("Unknown listener state: \(String(describing: newState))")
            }
        }

        return listener
    }

    private func updateState(_ newState: ServiceState) {
        switch newState {
        case .active:
            advertisingDelegate?.serviceDidStartAdvertising(service)
        case .inactive:
            advertisingDelegate?.serviceDidStopAdvertising(service)
            listener = nil
        case let .error(error):
            advertisingDelegate?.serviceDidEncounterError(service, error: error)
        }
        state = newState
    }

}
