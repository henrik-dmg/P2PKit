//
//  DataChunkReceiver.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.04.25.
//

import Foundation

final class DataChunkReceiver {

    // MARK: - Properties

    let endOfMessageSignal: Data
    let endOfMessageSignalSize: Int

    private var finalisedChunks: [String: Data] = [:]
    private var receivedChunks: [String: Data] = [:]

    // MARK: - Init

    init(endOfMessageSignal: Data) {
        self.endOfMessageSignal = endOfMessageSignal
        self.endOfMessageSignalSize = endOfMessageSignal.count
    }

    // MARK: - Methods

    func receive(_ data: Data, from peerID: String) -> Bool {
        finalisedChunks[peerID] = nil
        receiveChunk(data, from: peerID)

        if receivedChunks[peerID]?.suffix(endOfMessageSignalSize) == endOfMessageSignal {
            if let finalisedData = receivedChunks[peerID]?.dropLast(endOfMessageSignalSize) {
                finalisedChunks[peerID] = finalisedData.isEmpty ? nil : finalisedData
            }
            receivedChunks[peerID] = nil
            return true
        }

        return false
    }

    func allReceivedData(from peerID: String) -> Data? {
        finalisedChunks[peerID]
    }

    func wipeReceivedData(from peerID: String) {
        finalisedChunks[peerID] = nil
        receivedChunks[peerID] = nil
    }

    // MARK: - Helpers

    private func receiveChunk(_ data: Data, from peerID: String) {
        if receivedChunks[peerID] != nil {
            receivedChunks[peerID]?.append(data)
        } else {
            receivedChunks[peerID] = data
        }
    }

}
