//
//  BonjourDiscoveryService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 07.03.25.
//

import Network
import SwiftUI
import OSLog

@Observable
public final class BonjourDiscoveryService: BonjourDataTransferService, PeerDiscoveryService {

    // MARK: - Properties

    public private(set) var state: ServiceState = .inactive

    public var availablePeers: [P] {
        Array(discoveredPeers.values)
    }

    private var discoveredPeers: [ID: P] = [:]
    @ObservationIgnored
    private var browser: NWBrowser?
    @ObservationIgnored
    private let browserQueue = DispatchQueue(label: "browserQueue")

    private let logger = Logger.bonjour("discovery")

    // MARK: - PeerDiscoveryService

    public func startDiscoveringPeers() {
        guard browser == nil else {
            return  // TODO: Throw error
        }
        browser = makeBrowser()
        browser?.start(queue: browserQueue)
        state = .active
    }

    public func stopDiscoveringPeers() {
        browser?.cancel()
        browser = nil
        discoveredPeers.removeAll()
        state = .inactive
    }

    // MARK: - Helpers

    private func makeBrowser() -> NWBrowser {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true  // Allow discovery on AWDL, etc.

        let descriptor = NWBrowser.Descriptor.bonjour(type: service.type, domain: nil)
        let browser = NWBrowser(for: descriptor, using: parameters)
        browser.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }
            switch newState {
            case .setup:
                logger.info("Browser setup")
            case .ready:
                logger.info("Browser ready")
            case let .waiting(error):
                logger.error("Browser waiting: \(error)")
            case let .failed(error):
                logger.error("Browser failed: \(error)")
            case .cancelled:
                logger.info("Browser was stopped")
            @unknown default:
                logger.warning("Unknown browser state: \(String(describing: newState))")
            }
        }
        browser.browseResultsChangedHandler = { [weak self] updated, changes in
            print("Browser results changed:")
            for change in changes {
                switch change {
                case let .added(result):
                    let peer = BonjourPeer(endpoint: result.endpoint)

                    self?.logger.debug("+ \(peer.id)")
                    self?.logger.debug("+ \(result.interfaces.debugDescription)")

                    self?.discoveredPeers[peer.id] = peer
                case let .removed(result):
                    let peer = BonjourPeer(endpoint: result.endpoint)

                    self?.logger.debug("- \(peer.id)")
                    self?.logger.debug("- \(result.interfaces)")

                    self?.discoveredPeers[peer.id] = nil
                case let .changed(old, new, flags):
                    let oldPeer = BonjourPeer(endpoint: old.endpoint)
                    let newPeer = BonjourPeer(endpoint: new.endpoint)

                    self?.logger.debug("± \(oldPeer.id) -> \(newPeer.id)")
                    self?.logger.debug("± \(old.endpoint.debugDescription) -> \(new.endpoint.debugDescription)")
                    self?.logger.debug("± \(String(describing: flags))")
                    self?.logger.debug("± \(old.interfaces.debugDescription) -> \(new.interfaces.debugDescription)")

                    self?.discoveredPeers[oldPeer.id] = nil
                    self?.discoveredPeers[newPeer.id] = newPeer
                case .identical:
                    continue
                @unknown default:
                    self?.logger.warning("Unknown change: \(String(describing: change))")
                }
            }
        }

        return browser
    }

}
