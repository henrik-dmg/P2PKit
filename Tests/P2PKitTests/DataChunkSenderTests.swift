//
//  DataChunkSenderTests.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.04.25.
//

import CoreBluetooth
import Foundation
import Testing

@testable import P2PKit

@Suite
struct DataChunkSenderTests {

    @Test
    func sendsAllData() throws {
        var writtenChunks: [Data] = []

        let sender = DataChunkSender(endOfMessageSignal: .bluetoothEOM)
        sender.queue("Hello World".data(using: .utf8)!, to: "test") {
            3
        } chunkWriteHandler: { chunk in
            print("Writing \(chunk) (size: \(chunk.count))")
            writtenChunks.append(chunk)
        }

        repeat {
            sender.sendNextChunk(for: "test")
        } while sender.markChunkAsSent(for: "test")

        #expect(writtenChunks.count == 5)
        #expect(Data(writtenChunks.joined()) == "Hello World".data(using: .utf8)! + .bluetoothEOM)
    }

}
