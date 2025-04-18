//
//  PeerDiscoveryService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 07.03.25.
//

import Observation

public protocol PeerDiscoveryService<P>: PeerDataTransferService {

    var availablePeers: [P] { get }
    var state: ServiceState { get }

    func startDiscoveringPeers()
    func stopDiscoveringPeers()

}
