//
//  BonjourDiscoveryService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 07.03.25.
//

import Foundation
import Logging
import Network

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
        let parameters = NWParameters.applicationService
        parameters.includePeerToPeer = true  // Allow discovery on AWDL, etc.

        let descriptor = NWBrowser.Descriptor.bonjour(type: service.type, domain: nil)
        let browser = NWBrowser(for: descriptor, using: parameters)
        browser.stateUpdateHandler = { [weak self] newState in
            guard let self else {
                return
            }
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
        browser.browseResultsChangedHandler = { [weak self] _, changes in
            for change in changes {
                switch change {
                case let .added(result):
                    let peer = BonjourPeer(endpoint: result.endpoint)

                    self?.logger.debug("Discovered \(peer.id)", metadata: ["interfaces": .stringConvertible(result.interfaces)])
                    self?.discoveredPeers[peer.id] = peer
                case let .removed(result):
                    let peer = BonjourPeer(endpoint: result.endpoint)

                    self?.logger.debug("Lost \(peer.id)", metadata: ["interfaces": .stringConvertible(result.interfaces)])
                    self?.discoveredPeers[peer.id] = nil
                case let .changed(old, new, flags):
                    guard !flags.contains(.identical) else {
                        self?.logger.error("Ignoring identical peer update")
                        continue
                    }

                    let oldPeer = BonjourPeer(endpoint: old.endpoint)
                    let newPeer = BonjourPeer(endpoint: new.endpoint)

                    self?.logger.debug(
                        "Updated \(oldPeer.id)",
                        metadata: [
                            "old-peer-id": .string(oldPeer.id),
                            "new-peer-id": .string(newPeer.id),
                            "old-interfaces": .stringConvertible(old.interfaces),
                            "new-interfaces": .stringConvertible(new.interfaces),
                            "metadata-changed": .stringConvertible(flags.contains(.metadataChanged)),
                            "interface-added": .stringConvertible(flags.contains(.interfaceAdded)),
                            "interface-removed": .stringConvertible(flags.contains(.interfaceRemoved))
                        ]
                    )

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
