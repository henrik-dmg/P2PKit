//
//  BluetoothChunkSender.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.04.25.
//

import Foundation
import OSLog

final class BluetoothChunkSender {

    // MARK: - Nested Types

    typealias ChunkWriteHandler = (Data) -> Void

    // MARK: - Properties

    private var pendingChunks: [String: [Data]] = [:]
    private var writeHandlers: [String: ChunkWriteHandler] = [:]
    private let chunkSize: Int
    private let logger = Logger.bluetooth("chunksender")

    // MARK: - Init

    init(chunkSize: Int = .defaultBluetoothChunkSize) {
        self.chunkSize = chunkSize
    }

    // MARK: - Methods

    func queue(_ data: Data, to peerID: String, chunkWriteHandler: @escaping (Data) -> Void) {
        var chunks = stride(from: data.startIndex, to: data.endIndex, by: chunkSize).map { index in
            let fullChunkEndIndex = index.advanced(by: chunkSize)
            if data.endIndex < fullChunkEndIndex {
                return data.subdata(in: index..<data.endIndex)
            } else {
                return data.subdata(in: index..<fullChunkEndIndex)
            }
        }
        chunks.append(.bluetoothEOM)

        if pendingChunks[peerID] != nil {
            pendingChunks[peerID]?.append(contentsOf: chunks)
        } else {
            pendingChunks[peerID] = chunks
        }

        writeHandlers[peerID] = chunkWriteHandler
    }

    func markChunkAsSent(for peerID: String) {
        pendingChunks[peerID]?.removeFirst()
    }

    func sendNextChunk(for peerID: String) {
        guard let pendingChunks = pendingChunks[peerID] else {
            logger.info("No pending chunks to send")
            // No data cached that is still waiting to be sent
            return
        }

        guard let nextChunk = pendingChunks.first else {
            self.pendingChunks[peerID] = nil
            self.writeHandlers[peerID] = nil
            return
        }

        guard let writeHandler = writeHandlers[peerID] else {
            logger.warning("No write handler for \(peerID)")
            return
        }

        writeHandler(nextChunk)
    }

}
