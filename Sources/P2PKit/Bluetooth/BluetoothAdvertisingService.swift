//
//  BluetoothAdvertisingService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 07.04.25.
//

import CoreBluetooth
import Foundation
import Logging
import Observation

@Observable
@available(visionOS, unavailable)
public final class BluetoothAdvertisingService: NSObject, PeerAdvertisingService {

    // MARK: - Nested Types

    public typealias P = BluetoothPeer
    public typealias S = BluetoothService

    // MARK: - Properties

    public private(set) var state: ServiceState = .inactive
    public let ownPeerID: ID
    public let service: S
    public weak var delegate: PeerDataTransferServiceDelegate?
    public weak var advertisingDelegate: (any PeerAdvertisingServiceDelegate<S>)?

    public var connectedPeers: [ID] {
        Array(centrals.keys)
    }

    private var centrals: [ID: CBCentral] = [:]
    private let peripheralManager: CBPeripheralManager
    private let peripheralQueue: DispatchQueue

    private let chunkReceiver: DataChunkReceiver
    private let chunkSender: DataChunkSender

    private let logger = Logger.bluetooth("advertising")
    private let byteCountFormatter = ByteCountFormatter.default

    @ObservationIgnored
    private lazy var cbService: CBMutableService = makeService()
    @ObservationIgnored
    private lazy var characteristic: CBMutableCharacteristic = makeCharacteristic()

    // MARK: - Init

    public init(ownPeerID: ID, service: S, endOfMessageSignal: Data) {
        self.ownPeerID = ownPeerID
        self.service = service
        peripheralQueue = DispatchQueue(label: "peripheralQueue")
        peripheralManager = CBPeripheralManager(delegate: nil, queue: peripheralQueue, options: nil)
        chunkReceiver = DataChunkReceiver(endOfMessageSignal: endOfMessageSignal)
        chunkSender = DataChunkSender(endOfMessageSignal: endOfMessageSignal)
        super.init()
        peripheralManager.delegate = self
    }

    // MARK: - PeerAdvertisingService

    public func startAdvertisingService() {
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [cbService.uuid],
            CBAdvertisementDataLocalNameKey: ownPeerID,
        ]
        peripheralManager.startAdvertising(advertisementData)
    }

    public func stopAdvertisingService() {
        peripheralManager.stopAdvertising()
        peripheralQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateState(self?.peripheralManager.isAdvertising == true ? .active : .inactive)
        }
    }

    // MARK: - Helpers

    private func makeService() -> CBMutableService {
        let transferService = CBMutableService(type: service.uuid, primary: true)
        transferService.characteristics = [characteristic]
        return transferService
    }

    private func makeCharacteristic() -> CBMutableCharacteristic {
        CBMutableCharacteristic(
            type: service.characteristicUUID,
            properties: [.read, .notify, .write, .writeWithoutResponse],
            value: nil,
            permissions: [.readable, .writeable]
        )
    }

    private func updateState(_ newState: ServiceState) {
        switch newState {
        case .active:
            logger.info("Peripheral manager started advertising")
            advertisingDelegate?.serviceDidStartAdvertising(service)
        case .inactive:
            logger.info("Peripheral manager stopped advertising")
            advertisingDelegate?.serviceDidStopAdvertising(service)
        case let .error(error):
            logger.error("Advertiser did not start: \(error)")
        }
        state = newState
    }

    private func peerID(for central: CBCentral) -> ID {
        central.identifier.uuidString
    }

    private func handlePeripheralConnected(_ central: CBCentral) {
        let peerID = peerID(for: central)
        centrals[peerID] = central
        delegate?.serviceDidConnectToPeer(with: peerID)
    }

    private func handlePeripheralDisconnected(_ central: CBCentral) {
        let peerID = peerID(for: central)
        centrals[peerID] = nil
        delegate?.serviceDidDisconnectFromPeer(with: peerID)
    }

}

// MARK: - PeerDataTransferService

@available(visionOS, unavailable)
extension BluetoothAdvertisingService: PeerDataTransferService {

    public func connect(to peer: BluetoothPeer) {
        logger.error("Connect should never be called on peripheral mode")
    }

    public func send(_ data: Data, to peerID: ID) async throws {
        guard let central = centrals[peerID] else {
            logger.error("No central found for peer \(peerID)")
            return
        }

        logger.info("Sending \(byteCountFormatter.string(fromByteCount: Int64(data.count))) to peer \(peerID)")
        chunkSender.queue(data, to: peerID) {
            central.maximumUpdateValueLength
        } chunkWriteHandler: { [weak self] chunk in
            guard let self else {
                return
            }

            let wasValueUpdated = peripheralManager.updateValue(chunk, for: characteristic, onSubscribedCentrals: [central])

            if wasValueUpdated {
                logger.debug("Wrote \(chunk.count) bytes")
                if chunkSender.markChunkAsSent(for: peerID) {
                    chunkSender.sendNextChunk(for: peerID)
                }
            } else {
                logger.warning("Failed to write \(chunk.count) bytes. Most likely because queue is full.")
            }
        }
        chunkSender.sendNextChunk(for: peerID)
    }

    public func disconnect(from peerID: ID) {
        logger.error("Can't disconnect from CBCentral connections when in peripheral mode.")

        // Remove the central from our tracking
        centrals[peerID] = nil
        delegate?.serviceDidDisconnectFromPeer(with: peerID)
    }

    public func disconnectAll() {
        for id in centrals.keys {
            disconnect(from: id)
        }
    }

}

// MARK: - CBPeripheralManagerDelegate

@available(visionOS, unavailable)
extension BluetoothAdvertisingService: CBPeripheralManagerDelegate {

    public func peripheralManagerDidUpdateState(_ peripheralManager: CBPeripheralManager) {
        switch peripheralManager.state {
        case .poweredOn:
            logger.info("Peripheral manager is powered on")
            peripheralManager.add(cbService)
        case .poweredOff:
            logger.info("Peripheral manager is powered off")
        case .unauthorized:
            logger.info("Peripheral manager is unauthorized")
        case .unsupported:
            logger.info("Peripheral manager is unsupported")
        case .resetting:
            logger.info("Peripheral manager is resetting")
        case .unknown:
            logger.info("Peripheral manager state is unknown")
        @unknown default:
            logger.warning(
                "Unknown peripheral manager state: \(String(describing: peripheralManager.state))"
            )
        }
    }

    public func peripheralManager(
        _ peripheraManagerl: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        logger.info("Central subscribed to characteristic \(characteristic.uuid)")
        handlePeripheralConnected(central)
    }

    public func peripheralManager(
        _ peripheralManager: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        logger.info("Central unsubscribed from characteristic \(characteristic.uuid)")
        handlePeripheralDisconnected(central)
    }

    public func peripheralManager(_ peripheralManager: CBPeripheralManager, didAdd service: CBService, error: (any Error)?) {
        logger.info("Peripheral manager added service \(service.uuid)")
    }

    public func peripheralManagerDidStartAdvertising(_ peripheralManager: CBPeripheralManager, error: (any Error)?) {
        if let error {
            updateState(.error(error))
            return
        }
        updateState(.active)
    }

    public func peripheralManagerIsReady(toUpdateSubscribers peripheralManager: CBPeripheralManager) {
        logger.info("Peripheral manager is ready to update subscribers")
        // Simply using the first peer here is maybe a bit sub-optimal but in peripheral mode
        // we don't get callbacks for which specific device a chunk was written
        guard let firstPeerID = connectedPeers.first else {
            logger.warning("No connected peers to send chunks to")
            return
        }
        chunkSender.sendNextChunk(for: firstPeerID)
    }

    public func peripheralManager(_ peripheralManager: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        logger.info("Peripheral manager received \(requests.count) write requests")
        for request in requests {
            guard let data = request.value else {
                logger.warning("Responding to write request with invalid attribute value length")
                peripheralManager.respond(to: request, withResult: .invalidAttributeValueLength)
                return
            }

            logger.debug("Responding to write request with success")
            peripheralManager.respond(to: request, withResult: .success)

            let peerID = request.central.identifier.uuidString
            logger.trace("Received \(byteCountFormatter.string(fromByteCount: Int64(data.count))) (partial) from \(peerID)")

            if chunkReceiver.receive(data, from: peerID), let completeData = chunkReceiver.allReceivedData(from: peerID) {
                logger.info("Received \(byteCountFormatter.string(fromByteCount: Int64(completeData.count))) from \(peerID)")
                delegate?.serviceReceived(data: completeData, from: peerID)
            }
        }
    }

    public func peripheralManager(_ peripheralManager: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        logger.info("Peripheral manager received read request")
        peripheralManager.respond(to: request, withResult: .requestNotSupported)
    }

}
