//
//  ServiceType.swift
//  P2PChat
//
//  Created by Henrik Panhans on 23.03.25.
//

import Foundation

public enum ServiceType: String, Hashable, CaseIterable {

    case bluetooth
    case bonjour
    case multipeer

    public var name: String {
        rawValue.localizedCapitalized
    }

}
