//
//  BluetoothInformationService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 07.04.25.
//

import SwiftUI

public struct BluetoothInformationService: PeerInformationService {

    // MARK: - Nested Types

    public typealias P = BluetoothPeer

    // MARK: - Init

    public init() {}

    // MARK: - Methods

    public func peerCellView(for peer: P) -> some View {
        VStack(alignment: .leading) {
            LabeledContent("Name", value: peer.name)
            LabeledContent("ID", value: peer.id)
        }
    }

    public func peerInformationView(for peer: P) -> some View {
        NavigationView {
            List {
                LabeledContent("Name", value: peer.name)
                LabeledContent("ID", value: peer.id)
            }
        }
    }

}
