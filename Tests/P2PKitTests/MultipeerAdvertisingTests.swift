//
//  MultipeerAdvertisingTests.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.04.25.
//

import Foundation
import Testing

@testable import P2PKit

@Suite("Multipeer Advertising Tests")
struct MultipeerAdvertisingTests: AdvertisingTests {

    let service = MultipeerService(type: "p2pchat-test")

    @Test
    func serviceGetsAdvertised() async throws {
        let advertiser = MultipeerAdvertisingService(ownPeerID: UUID().uuidString, service: service)

        advertiser.startAdvertisingService()
        try await Task.sleep(for: .seconds(2))
        #expect(advertiser.state == .active)

        advertiser.stopAdvertisingService()
        try await Task.sleep(for: .seconds(2))
        #expect(advertiser.state == .inactive)
    }

}
