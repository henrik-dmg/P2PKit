//
//  BluetoothAdvertisingTests.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.04.25.
//

import CoreBluetooth
import Foundation
import Testing

@testable import P2PKit

@Suite("Bluetooth Advertising Tests", .disabled())
struct BluetoothAdvertisingTests: AdvertisingTests {

    let service = BluetoothService(uuid: CBUUID(), characteristicUUID: CBUUID())

    @Test
    func serviceGetsAdvertised() async throws {
        let advertiser = BluetoothAdvertisingService(ownPeerID: UUID().uuidString, service: service, endOfMessageSignal: "EOM".data(using: .utf8)!)

        advertiser.startAdvertisingService()
        try await Task.sleep(for: .seconds(2))
        #expect(advertiser.state == .active)

        advertiser.stopAdvertisingService()
        try await Task.sleep(for: .seconds(2))
        #expect(advertiser.state == .inactive)
    }

}
