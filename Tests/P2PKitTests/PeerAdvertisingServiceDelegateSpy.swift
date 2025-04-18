//
//  PeerAdvertisingServiceDelegateSpy.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.04.25.
//

import Foundation
import P2PKit

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
