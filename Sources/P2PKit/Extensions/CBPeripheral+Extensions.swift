//
//  CBPeripheral+Extensions.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.04.25.
//

import CoreBluetooth

extension CBPeripheral {

    var safeName: String {
        name ?? identifier.uuidString
    }

}
