//
//  PeerAdvertisingService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 23.03.25.
//

import Observation

public protocol PeerAdvertisingService<P>: PeerDataTransferService {

    var state: ServiceState { get }

    var advertisingDelegate: (any PeerAdvertisingServiceDelegate<Self.S>)? { get set }

    func startAdvertisingService()
    func stopAdvertisingService()

}

public protocol PeerAdvertisingServiceDelegate<S>: AnyObject {

    associatedtype S: Service

    func serviceDidStartAdvertising(_ service: Service)
    func serviceDidStopAdvertising(_ service: Service)

}
