//
//  PeerInformationService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 22.03.25.
//

import Observation
import SwiftUI

public protocol PeerInformationService<P> {

    associatedtype P: Peer
    associatedtype CellView: View
    associatedtype InformationView: View

    func peerCellView(for peer: P) -> CellView
    func peerInformationView(for peer: P) -> InformationView

}
