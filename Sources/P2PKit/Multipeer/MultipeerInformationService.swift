//
//  MultipeerInformationService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 23.03.25.
//

import SwiftUI

public struct MultipeerInformationService: PeerInformationService {

    // MARK: - Nested Types

    public typealias P = MultipeerPeer

    // MARK: - Init

    public init() {}

    // MARK: - Methods

    public func peerCellView(for peer: P) -> some View {
        VStack(alignment: .leading) {
            Text(peer.id)
            Text("Multipeer peer")
        }
    }

    public func peerInformationView(for peer: P) -> some View {
        NavigationView {
            List {
                LabeledContent("ID", value: peer.id)
            }
        }
    }

}
