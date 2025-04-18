//
//  Peer.swift
//  P2PChat
//
//  Created by Henrik Panhans on 07.03.25.
//

public protocol Peer: Identifiable where ID == String {

    var id: String { get }

}
