//
//  BluetoothService.swift
//  P2PKit
//
//  Created by Henrik Panhans on 10.04.25.
//

import CoreBluetooth

public struct BluetoothService: Service {

    // MARK: - Properties

    public let uuid: CBUUID
    public let characteristicUUID: CBUUID

    // MARK: - Init

    public init(uuid: CBUUID, characteristicUUID: CBUUID) {
        self.uuid = uuid
        self.characteristicUUID = characteristicUUID
    }

}
