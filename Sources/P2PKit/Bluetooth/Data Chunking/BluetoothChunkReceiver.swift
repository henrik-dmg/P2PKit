//
//  BluetoothChunkReceiver.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.04.25.
//

import Foundation

final class BluetoothChunkReceiver {

    // MARK: - Properties

    private var finalisedChunks: [String: Data] = [:]
    private var receivedChunks: [String: Data] = [:]

    private let endOfMessageSignal: Data

    // MARK: - Init

    init(endOfMessageSignal: Data) {
        self.endOfMessageSignal = endOfMessageSignal
    }

    // MARK: - Methods

    func receive(_ data: Data, from peerID: String) -> Bool {
        // If we receive the EOM signal, store the finalised data and return true
        // to singal that we received the message until the end.
        if data == endOfMessageSignal {
            finalisedChunks[peerID] = receivedChunks[peerID]
            receivedChunks[peerID] = nil
            return true
        }

        // If we start receiving non-EOM chunks, clear finalised data and start over
        finalisedChunks[peerID] = nil

        if receivedChunks[peerID] != nil {
            receivedChunks[peerID]?.append(data)
        } else {
            receivedChunks[peerID] = data
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

}
