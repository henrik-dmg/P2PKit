//
//  BluetoothChunkSenderTests.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.04.25.
//

import CoreBluetooth
import Foundation
import Testing

@testable import P2PKit

@Suite
struct BluetoothChunkSenderTests {

    @Test
    func sendsAllData() throws {
        var writtenChunks: [Data] = []

        let sender = BluetoothChunkSender(endOfMessageSignal: .bluetoothEOM)
        sender.queue("Hello World".data(using: .utf8)!, to: "test") {
            3
        } chunkWriteHandler: { chunk in
            writtenChunks.append(chunk)
        }

        repeat {
            sender.sendNextChunk(for: "test")
        } while sender.markChunkAsSent(for: "test")

        #expect(writtenChunks.count == 5)
        let writtenData = writtenChunks.prefix(4).joined()
        #expect(Data(writtenData) == "Hello World".data(using: .utf8))
        #expect(writtenChunks.last == .bluetoothEOM)
    }

}
