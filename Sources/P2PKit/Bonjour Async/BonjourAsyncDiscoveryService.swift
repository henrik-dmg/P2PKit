//
//  BonjourAsyncDiscoveryService.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.07.25.
//

import Foundation
import Logging
import Network

@available(iOS 26, macOS 26, *)
@Observable
public final class BonjourAsyncDiscoveryService: BonjourAsyncDataTransferService, PeerDiscoveryService {

    // MARK: - Properties

    public private(set) var state: ServiceState = .inactive

    public var availablePeers: [P] {
        Array(discoveredPeers.values)
    }

    private var discoveredPeers: [ID: P] = [:]

    @ObservationIgnored
    private var browser: NetworkBrowser<Bonjour>?
    @ObservationIgnored
    private var browserTask: Task<Void, Never>?
    @ObservationIgnored
    private var browserResult: NetworkBrowser<Bonjour>.Result<[BonjourPeer]> = .continue

    private let logger = Logger.bonjour("discovery-async")

    // MARK: - PeerDiscoveryService

    public func startDiscoveringPeers() {
        guard browser == nil else {
            return  // TODO: Throw error
        }
        let browser = makeBrowser()
        self.browser = browser
        browserTask = Task { [weak self] in
            do {
                try await browser.run { [weak self] availableEndpoints in
                    print("Results changed")
                    try await self?.handleResultChange(availableEndpoints)
                }
            } catch {
                if error is CancellationError {
                    self?.logger.trace("Browser was cancelled")
                    self?.browser = nil
                    self?.state = .inactive
                    self?.disconnectAll()
                } else {
                    self?.logger.error("Error running browser: \(error)")
                    self?.state = .error(error)
                }
            }
        }
    }

    public func stopDiscoveringPeers() {
        browserTask?.cancel()
    }

    // MARK: - Helpers

    private func makeBrowser() -> NetworkBrowser<Bonjour> {
        let bonjour = Bonjour.bonjour(service.type)

        let parameters = NWParameters.applicationService
        parameters.includePeerToPeer = false  // Allow discovery on AWDL, etc.
        let browser = NetworkBrowser(for: bonjour, using: parameters)

        browser.onStateUpdate { [weak self] browser, newState in
            guard let self else {
                return
            }
            switch newState {
            case .setup:
                logger.info("Browser setup")
            case .ready:
                logger.info("Browser ready")
                state = .active
            case let .waiting(error):
                logger.error("Browser waiting: \(error)")
                state = .error(error)
            case let .failed(error):
                logger.error("Browser failed: \(error)")
                state = .error(error)
            case .cancelled:
                logger.info("Browser was stopped")
                state = .inactive
            @unknown default:
                logger.warning("Unknown browser state: \(String(describing: newState))")
            }
        }

        return browser
    }

    private func handleResultChange(_ availableEndpoints: [Bonjour.Endpoint]) async throws {
        for endpoint in availableEndpoints {
            let peer = BonjourPeer(endpoint: endpoint.nwEndpoint)
            discoveredPeers[peer.id] = peer
        }
    }

}
