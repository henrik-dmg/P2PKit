//
//  DelegateSpy.swift
//  P2PKit
//
//  Created by Henrik Panhans on 17.04.25.
//

import Foundation
import P2PKit

class PeerDataTransferServiceDelegateSpy: NSObject, PeerDataTransferServiceDelegate {

    var serviceDidFailToConnectToPeerHandler: ((String, any Error) -> Void)?
    var serviceDidConnectToPeerHandler: ((String) -> Void)?
    var serviceReceivedHandler: ((Data, String) -> Void)?
    var serviceDidDisconnectFromPeerHandler: ((String) -> Void)?

    func serviceDidFailToConnectToPeer(with id: String, error: any Error) {
        serviceDidFailToConnectToPeerHandler?(id, error)
    }

    func serviceDidConnectToPeer(with id: String) {
        serviceDidConnectToPeerHandler?(id)
    }

    func serviceReceived(data: Data, from peerID: String) {
        serviceReceivedHandler?(data, peerID)
    }

    func serviceDidDisconnectFromPeer(with id: String) {
        serviceDidDisconnectFromPeerHandler?(id)
    }

}

class PeerAdvertisingServiceDelegateSpy<S: Service>: NSObject, PeerAdvertisingServiceDelegate {

    var serverDidStartAdvertisingHandler: ((any Service) -> Void)?
    var serviceDidStopAdvertisingHandler: ((any Service) -> Void)?

    func serviceDidStartAdvertising(_ service: any Service) {
        serverDidStartAdvertisingHandler?(service)
    }

    func serviceDidStopAdvertising(_ service: any Service) {
        serviceDidStopAdvertisingHandler?(service)
    }

}
