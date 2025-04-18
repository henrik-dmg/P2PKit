//
//  PeerDataTransferService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 07.03.25.
//

import Foundation
import Observation

public protocol PeerDataTransferService<P>: AnyObject, Observable {

    associatedtype P: Peer
    associatedtype S: Service
    typealias ID = P.ID

    var ownPeerID: ID { get }
    var connectedPeers: [ID] { get }
    var service: S { get }

    var delegate: PeerDataTransferServiceDelegate? { get set }

    func connect(to peer: P)
    func send(_ data: Data, to peerID: ID) async throws
    func disconnect(from peerID: ID)
    func disconnectAll()

}

public protocol PeerDataTransferServiceDelegate: AnyObject {

    func serviceDidFailToConnectToPeer(with id: String, error: Error)
    func serviceDidConnectToPeer(with id: String)
    func serviceReceived(data: Data, from peerID: String)
    func serviceDidDisconnectFromPeer(with id: String)

}
