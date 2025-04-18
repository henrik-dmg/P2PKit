//
//  BonjourAdvertisingTests.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.04.25.
//

import Foundation
import Testing

@testable import P2PKit

@Suite("Bonjour Advertising Tests")
struct BonjourAdvertisingTests: AdvertisingTests {

    let service = BonjourService(type: "_p2pchat._tcp")

    @Test
    func serviceGetsAdvertised() async throws {
        let advertiser = BonjourAdvertisingService(ownPeerID: UUID().uuidString, service: service)

        advertiser.startAdvertisingService()
        try await Task.sleep(for: .seconds(2))
        #expect(advertiser.state == .active)

        advertiser.stopAdvertisingService()
        try await Task.sleep(for: .seconds(2))
        #expect(advertiser.state == .inactive)
    }

}
