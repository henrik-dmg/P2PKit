//
//  BluetoothDataTransferService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 07.04.25.
//

import CoreBluetooth
import Foundation
import Logging
import Observation

@Observable
public class BluetoothDiscoveryService: NSObject, PeerDiscoveryService {

    // MARK: - Nested Types

    public typealias P = BluetoothPeer
    public typealias S = BluetoothService

    // MARK: - Properties

    public private(set) var state: ServiceState = .inactive
    public let ownPeerID: ID
    public let service: S
    public weak var delegate: PeerDataTransferServiceDelegate?

    public var availablePeers: [P] {
        Array(discoveredPheripherals.values)
    }
    public var connectedPeers: [ID] {
        Array(connectedPheripherals.keys)
    }

    private var discoveredPheripherals: [ID: P] = [:]
    private var connectedPheripherals: [ID: CBPeripheral] = [:]
    @ObservationIgnored
    private var writeCharacteristics: [ID: CBCharacteristic] = [:]
    private let centralManager: CBCentralManager
    private let centralsQueue: DispatchQueue

    private let chunkReceiver: DataChunkReceiver
    private let chunkSender: DataChunkSender

    private let logger = Logger.bluetooth("discovery")
    private let byteCountFormatter = ByteCountFormatter()

    // MARK: - Init

    public init(ownPeerID: ID, service: S, endOfMessageSingal: Data) {
        self.ownPeerID = ownPeerID
        self.service = service
        centralsQueue = DispatchQueue(label: "bluetoothQueue")
        centralManager = CBCentralManager(delegate: nil, queue: centralsQueue)
        chunkReceiver = DataChunkReceiver(endOfMessageSignal: endOfMessageSingal)
        chunkSender = DataChunkSender(endOfMessageSignal: endOfMessageSingal)
        super.init()
        centralManager.delegate = self
    }

    // MARK: - PeerDiscoveryService

    public func startDiscoveringPeers() {
        guard centralManager.state == .poweredOn else {
            logger.error("Bluetooth is not powered on")
            return
        }

        let options: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ]

        centralManager.scanForPeripherals(withServices: [service.uuid], options: options)
        updateState()
    }

    public func stopDiscoveringPeers() {
        centralManager.stopScan()
        discoveredPheripherals.removeAll()
        updateState()
    }

    // MARK: - Helpers

    private func updateState() {
        state = centralManager.isScanning ? .active : .inactive
    }

    private func peerID(for peripheral: CBPeripheral) -> ID {
        peripheral.identifier.uuidString
    }

    private func handlePeripheralConnected(_ peripheral: CBPeripheral) {
        let peerID = peerID(for: peripheral)
        connectedPheripherals[peerID] = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    private func handlePeripheralDisconnected(_ peripheral: CBPeripheral) {
        let peerID = peerID(for: peripheral)
        connectedPheripherals[peerID] = nil
        writeCharacteristics[peerID] = nil
        chunkReceiver.wipeReceivedData(from: peerID)
        delegate?.serviceDidDisconnectFromPeer(with: peerID)
    }

}

// MARK: - PeerDataTransferService

extension BluetoothDiscoveryService: PeerDataTransferService {

    public func connect(to peer: BluetoothPeer) {
        guard centralManager.state == .poweredOn else {
            logger.error("Bluetooth is not powered on")
            return
        }

        logger.info("Connecting to \(peer.name)")
        centralManager.connect(peer.peripheral, options: [:])
    }

    public func send(_ data: Data, to peerID: ID) async throws {
        guard let peripheral = connectedPheripherals[peerID], let characteristic = writeCharacteristics[peerID] else {
            return
        }

        logger.info("Sending \(byteCountFormatter.string(fromByteCount: Int64(data.count))) to peer \(peerID)")
        chunkSender.queue(data, to: peerID) {
            peripheral.maximumWriteValueLength(for: .withResponse)
        } chunkWriteHandler: { chunk in
            peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
        }
        chunkSender.sendNextChunk(for: peerID)
    }

    public func disconnect(from peerID: ID) {
        guard let peripheral = connectedPheripherals[peerID] else {
            logger.error("No peripheral \(peerID) to disconnect from")
            return
        }

        centralManager.cancelPeripheralConnection(peripheral)
    }

    public func disconnectAll() {
        for peripheral in connectedPheripherals.values {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothDiscoveryService: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ centralManager: CBCentralManager) {
        switch centralManager.state {
        case .poweredOn:
            logger.info("Bluetooth is powered on")
        case .poweredOff:
            logger.info("Bluetooth is powered off")
        case .unauthorized:
            logger.warning("Bluetooth is unauthorized")
        case .unsupported:
            logger.warning("Bluetooth is unsupported")
        case .resetting:
            logger.info("Bluetooth is resetting")
        case .unknown:
            logger.warning("Bluetooth state is unknown")
        @unknown default:
            logger.warning("Unknown Bluetooth state")
        }
    }

    public func centralManager(
        _ centralManager: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let peerID = peerID(for: peripheral)
        logger.info("Discovered peripheral \(peerID) with RSSI \(RSSI)")
        discoveredPheripherals[peerID] = BluetoothPeer(
            peripheral: peripheral,
            advertisementData: advertisementData
        )
    }

    public func centralManager(_ centralManager: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let peerID = peerID(for: peripheral)
        logger.info("Connected to peripheral \(peerID), but haven't discovered services yet")
        handlePeripheralConnected(peripheral)
    }

    public func centralManager(
        _ centralManager: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        let peerID = peerID(for: peripheral)
        logger.error("Failed to connect to peripheral \(peerID): \(error?.localizedDescription ?? "reason unknown")")
    }

    public func centralManager(
        _ centralManager: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        let peerID = peerID(for: peripheral)
        if let error {
            logger.error("Error disconnecting from : \(error)")
        } else {
            logger.info("Disconnected from peripheral \(peerID)")
        }
        handlePeripheralDisconnected(peripheral)
    }

}

// MARK: - CBPeripheralDelegate

extension BluetoothDiscoveryService: CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            logger.error("Error discovering services: \(error!)")
            return
        }

        guard let services = peripheral.services else {
            return
        }

        for service in services where service.uuid == self.service.uuid {
            logger.debug("Discoverred service \(service.uuid) for peripheral \(peripheral.safeName)")
            peripheral.discoverCharacteristics([self.service.characteristicUUID], for: service)
            break
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let peerID = peerID(for: peripheral)

        if let error {
            logger.error("Error discovering characteristic for peripheral \(peerID): \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics, !characteristics.isEmpty else {
            logger.error("No characteristics for service found for peripheral \(peerID)")
            return
        }

        logger.info("Discovered \(characteristics.count) characteristics for peripheral \(peerID)")

        for characteristic in characteristics {
            let properties = characteristic.properties
            if properties.contains(.write) || properties.contains(.writeWithoutResponse) {
                if writeCharacteristics[peerID] != nil {
                    logger.warning("Already has a write characteristic for peripheral \(peerID)")
                }
                writeCharacteristics[peerID] = characteristic
            }

            peripheral.setNotifyValue(true, for: characteristic)
        }

        if writeCharacteristics[peerID] != nil {
            logger.debug("Fully connected to peer \(peerID)")
            delegate?.serviceDidConnectToPeer(with: peerID)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        logger.warning("Peripheral \(peripheral.safeName) did modify services")
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // First handle error if any
        if let error {
            logger.error("Error updating value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            return
        }

        let peerID = peerID(for: peripheral)

        guard let data = characteristic.value else {
            logger.warning("Characterisic \(characteristic.uuid) value was updated but is nil")
            return
        }

        logger.trace("Received \(byteCountFormatter.string(fromByteCount: Int64(data.count))) (partial) from \(peerID)")

        if chunkReceiver.receive(data, from: peerID), let completeData = chunkReceiver.allReceivedData(from: peerID) {
            logger.info("Received \(byteCountFormatter.string(fromByteCount: Int64(completeData.count))) from \(peerID)")
            delegate?.serviceReceived(data: completeData, from: peerID)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let peerID = peerID(for: peripheral)

        // First handle error if any
        if let error {
            logger.error("Error writing value for characteristic \(characteristic.uuid): \(error)")
            chunkSender.sendNextChunk(for: peerID)
            return
        }

        logger.trace("Successfully wrote value for characteristic \(characteristic.uuid)")

        if chunkSender.markChunkAsSent(for: peerID) {
            chunkSender.sendNextChunk(for: peerID)
        }
    }

}
