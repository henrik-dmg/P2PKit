//
//  BluetoothPeer.swift
//  P2PChat
//
//  Created by Henrik Panhans on 07.04.25.
//

import CoreBluetooth

public struct BluetoothPeer: Peer {

    // MARK: - Properties

    public let peripheral: CBPeripheral
    public let advertisementData: [String: Any]

    public var id: ID {
        peripheral.identifier.uuidString
    }

    public var name: String {
        peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? id
    }

    // MARK: - Init

    public init(peripheral: CBPeripheral, advertisementData: [String : Any]) {
        self.peripheral = peripheral
        self.advertisementData = advertisementData
    }

}
