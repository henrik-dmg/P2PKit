//
//  BluetoothChunkSender.swift
//  P2PKit
//
//  Created by Henrik Panhans on 18.04.25.
//

import Foundation
import OSLog

final class DataChunkSender {

    // MARK: - Nested Types

    typealias ChunkWriteHandler = (Data) -> Void
    typealias ChunkSizeHandler = () -> Int

    // MARK: - Properties

    let endOfMessageSignal: Data
    let endOfMessageSignalSize: Int

    private var queuedData: [String: [Data]] = [:]
    private var writeHandlers: [String: ChunkWriteHandler] = [:]
    private var sizeHandlers: [String: ChunkSizeHandler] = [:]
    private var lastWrittenChunkSize: [String: Int] = [:]

    private let logger = Logger.bluetooth("chunksender")

    // MARK: - Init

    init(endOfMessageSignal: Data) {
        self.endOfMessageSignal = endOfMessageSignal
        self.endOfMessageSignalSize = endOfMessageSignal.count
    }

    // MARK: - Methods

    func queue(
        _ data: Data,
        to peerID: String,
        chunkSizeHandler: @escaping ChunkSizeHandler,
        chunkWriteHandler: @escaping ChunkWriteHandler
    ) {
        let dataWithEOM = data + endOfMessageSignal
        if queuedData[peerID] != nil {
            queuedData[peerID]?.append(dataWithEOM)
        } else {
            queuedData[peerID] = [dataWithEOM]
        }

        logger.debug("Queued \(dataWithEOM.count) bytes for \(peerID)")

        writeHandlers[peerID] = chunkWriteHandler
        sizeHandlers[peerID] = chunkSizeHandler
    }

    func markChunkAsSent(for peerID: String) -> Bool {
        guard let lastWrittenChunkSize = lastWrittenChunkSize[peerID] else {
            logger.warning("No last written chunk size for \(peerID)")
            return false
        }
        guard var firstChunkData = queuedData[peerID]?.first else {
            logger.warning("No data to remove for \(peerID)")
            return false
        }

        firstChunkData.removeFirst(lastWrittenChunkSize)

        if firstChunkData.isEmpty {
            queuedData[peerID]?.removeFirst()
            return queuedData[peerID]?.isEmpty == false
        } else {
            queuedData[peerID]?[0] = firstChunkData
        }

        return true
    }

    func sendNextChunk(for peerID: String) {
        guard let writeHandler = writeHandlers[peerID] else {
            logger.warning("No write handler for \(peerID)")
            return
        }
        guard let sizeHandler = sizeHandlers[peerID] else {
            logger.warning("No size handler for \(peerID)")
            return
        }

        guard let queuedDataForPeer = queuedData[peerID]?.first else {
            cleanUp(for: peerID)
            logger.info("No pending chunks to send")
            return
        }

        let chunkSize = sizeHandler()
        let endOfMessageSignalSize = self.endOfMessageSignalSize
        if chunkSize < endOfMessageSignalSize {
            logger.critical(
                "Chunk size should not be smaller than the end of message signal size: \(chunkSize) < \(endOfMessageSignalSize)"
            )
        }

        let chunk = Data(queuedDataForPeer.prefix(chunkSize))
        lastWrittenChunkSize[peerID] = chunk.count
        writeHandler(chunk)
    }

    private func cleanUp(for peerID: String) {
        queuedData[peerID] = nil
        writeHandlers[peerID] = nil
        sizeHandlers[peerID] = nil
        lastWrittenChunkSize[peerID] = nil
    }

}
