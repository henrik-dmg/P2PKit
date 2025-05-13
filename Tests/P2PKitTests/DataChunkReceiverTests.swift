//
//  DataChunkReceiverTests.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.04.25.
//

import CoreBluetooth
import Foundation
import Testing

@testable import P2PKit

@Suite
struct DataChunkReceiverTests {

    @Test
    func receivesCompleteMessage() async throws {
        let receiver = DataChunkReceiver(endOfMessageSignal: .defaultEndOfMessageSignal)
        #expect(!receiver.receive("Hello".data(using: .utf8)!, from: "test"))
        #expect(!receiver.receive("World".data(using: .utf8)!, from: "test"))
        #expect(receiver.receive(.defaultEndOfMessageSignal, from: "test"))

        let fullData = try #require(receiver.allReceivedData(from: "test"))
        #expect(fullData == "HelloWorld".data(using: .utf8))
    }

    @Test
    func receivesCompleteMessageWithEOMInLastChunk() async throws {
        let receiver = DataChunkReceiver(endOfMessageSignal: .defaultEndOfMessageSignal)
        #expect(!receiver.receive("Hello".data(using: .utf8)!, from: "test"))
        #expect(receiver.receive("World".data(using: .utf8)! + .defaultEndOfMessageSignal, from: "test"))

        let fullData = try #require(receiver.allReceivedData(from: "test"))
        #expect(fullData == "HelloWorld".data(using: .utf8))
    }

    @Test
    func receivesOnlyEOM() async throws {
        let receiver = DataChunkReceiver(endOfMessageSignal: .defaultEndOfMessageSignal)
        #expect(receiver.receive(.defaultEndOfMessageSignal, from: "test"))
        #expect(receiver.allReceivedData(from: "test") == nil)
    }

    @Test
    func wipesOldDataAfterEOM() async throws {
        let receiver = DataChunkReceiver(endOfMessageSignal: .defaultEndOfMessageSignal)
        #expect(!receiver.receive("Hello".data(using: .utf8)!, from: "test"))
        #expect(receiver.receive(.defaultEndOfMessageSignal, from: "test"))
        #expect(receiver.allReceivedData(from: "test") == "Hello".data(using: .utf8))

        #expect(!receiver.receive("World".data(using: .utf8)!, from: "test"))
        #expect(receiver.allReceivedData(from: "test") == nil)
        #expect(receiver.receive(.defaultEndOfMessageSignal, from: "test"))
        #expect(receiver.allReceivedData(from: "test") == "World".data(using: .utf8))
    }

}
