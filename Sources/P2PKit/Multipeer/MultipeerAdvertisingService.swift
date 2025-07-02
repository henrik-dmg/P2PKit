//
//  MultipeerAdvertisingService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 23.03.25.
//

import Logging
import MultipeerConnectivity
import Observation

@Observable
public final class MultipeerAdvertisingService: MultipeerDataTransferService, PeerAdvertisingService {

    // MARK: - Properties

    public private(set) var state: ServiceState = .inactive
    public weak var advertisingDelegate: (any PeerAdvertisingServiceDelegate<S>)?

    @ObservationIgnored
    private lazy var advertiser = makeAdvertiser()

    private let logger = Logger.multipeer("advertising")

    // MARK: - PeerDiscoveryService

    public func startAdvertisingService() {
        advertiser.startAdvertisingPeer()
        updateState(.active)
    }

    public func stopAdvertisingService() {
        advertiser.stopAdvertisingPeer()
        updateState(.inactive)
    }

    // MARK: - Helpers

    func makeAdvertiser() -> MCNearbyServiceAdvertiser {
        let advertiser = MCNearbyServiceAdvertiser(peer: ownMCPeerID, discoveryInfo: nil, serviceType: service.type)
        advertiser.delegate = self
        return advertiser
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

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerAdvertisingService: MCNearbyServiceAdvertiserDelegate {

    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        logger.info("Did receive invitation from \(peerID.displayName)")
        invitationHandler(true, session)
    }

    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
        logger.error("Advertiser did not start advertising service: \(error)")
        updateState(.error(error))
    }

}
