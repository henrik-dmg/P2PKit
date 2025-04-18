//
//  BonjourInformationService.swift
//  P2PChat
//
//  Created by Henrik Panhans on 23.03.25.
//

import SwiftUI

public struct BonjourInformationService: PeerInformationService {

    // MARK: - Nested Types

    public typealias P = BonjourPeer

    // MARK: - Init

    public init() {}

    // MARK: - Methods

    public func peerCellView(for peer: P) -> some View {
        VStack(alignment: .leading) {
            if let serviceConfiguration = peer.serviceConfiguration {
                Text(serviceConfiguration.name)
                Text(serviceConfiguration.domain)
                Text(serviceConfiguration.type)
            } else {
                Text(peer.id)
            }
        }
    }

    public func peerInformationView(for peer: P) -> some View {
        NavigationView {
            List {
                LabeledContent("ID", value: peer.id)
                if let serviceConfiguration = peer.serviceConfiguration {
                    LabeledContent("Name", value: serviceConfiguration.name)
                    LabeledContent("Domain", value: serviceConfiguration.domain)
                    LabeledContent("Type", value: serviceConfiguration.type)
                    if let interface = serviceConfiguration.interface {
                        LabeledContent("Interface", value: interface.name)
                    }
                }
            }
        }
    }

}
