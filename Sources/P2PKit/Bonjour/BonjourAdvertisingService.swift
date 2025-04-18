//
//  BonjourAdvertisingService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 23.03.25.
//

import Network
import OSLog
import Observation

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
            return  // TODO: Throw error
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
        listener = nil
        state = .inactive
    }

    // MARK: - Helpers

    private func makeListener() throws -> NWListener {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true  // Allow discovery on AWDL, etc.

        let service = NWListener.Service(name: ownPeerID, type: service.type)
        let listener = try NWListener(service: service, using: parameters)
        listener.stateUpdateHandler = { [weak self] (newState: NWListener.State) in
            guard let self else {
                return
            }
            switch newState {
            case .setup:
                logger.info("Listener setting up")
            case let .waiting(error):
                logger.error("Listener waiting with error: \(error)")
            case .ready:
                logger.info("Listener ready")
            case let .failed(error):
                logger.error("Listener error: \(error)")
            case .cancelled:
                logger.info("Listener stopped")
                disconnectAll()
            @unknown default:
                logger.warning("Unknown listener state: \(String(describing: newState))")
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.logger.info("New connection \(connection.debugDescription)")
            let peer = BonjourPeer(endpoint: connection.endpoint)
            self?.connect(with: connection, peerID: peer.id)
        }
        listener.newConnectionLimit = 1

        listener.serviceRegistrationUpdateHandler = { [weak self] registrationState in
            guard let self else { return }
            switch registrationState {
            case .add:
                updateState(.active)
            case .remove:
                updateState(.inactive)
            @unknown default:
                logger.warning("Unknown service registration state: \(String(describing: registrationState))")
            }
        }

        return listener
    }

    private func updateState(_ newState: ServiceState) {
        switch newState {
        case .active:
            logger.info("Service added")
            advertisingDelegate?.serviceDidStartAdvertising(service)
        case .inactive:
            logger.info("Service removed")
            advertisingDelegate?.serviceDidStopAdvertising(service)
        case let .error(error):
            logger.error("Advertiser did not start: \(error)")
        }
        state = newState
    }

}
