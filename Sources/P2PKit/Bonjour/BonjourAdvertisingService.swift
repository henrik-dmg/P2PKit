//
//  BonjourAdvertisingService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 23.03.25.
//

import Foundation
import Logging
import Network

@Observable
public final class BonjourAdvertisingService: BonjourDataTransferService, PeerAdvertisingService {

    // MARK: - Properties

    public private(set) var state: ServiceState = .inactive
    public weak var advertisingDelegate: (any PeerAdvertisingServiceDelegate<S>)?

    @ObservationIgnored
    private var listener: NWListener?
    @ObservationIgnored
    private let listenerQueue = DispatchQueue(label: "listenerQueue")

    private let logger = Logger.bonjour("advertising")

    // MARK: - PeerDiscoveryService

    public func startAdvertisingService() {
        guard listener == nil else {
            logger.error("Tried to start advertising service multiple times")
            return
        }
        do {
            listener = try makeListener()
            listener?.start(queue: listenerQueue)
        } catch {
            state = .error(error)
        }
    }

    public func stopAdvertisingService() {
        listener?.cancel()
    }

    // MARK: - Helpers

    private func makeListener() throws -> NWListener {
        let parameters = NWParameters.applicationService
        parameters.includePeerToPeer = false  // Allow discovery on AWDL, etc.

        let service = NWListener.Service(name: ownPeerID, type: service.type)
        let listener = try NWListener(service: service, using: parameters)
        listener.stateUpdateHandler = { [weak self] (newState: NWListener.State) in
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
                self?.updateState(.inactive)
                self?.disconnectAll()
            @unknown default:
                self?.logger.warning("Unknown listener state: \(String(describing: newState))")
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.logger.info("New connection \(connection.debugDescription)")
            let peer = BonjourPeer(endpoint: connection.endpoint)
            self?.connect(with: connection, peerID: peer.id)
        }

        listener.serviceRegistrationUpdateHandler = { [weak self] registrationState in
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
