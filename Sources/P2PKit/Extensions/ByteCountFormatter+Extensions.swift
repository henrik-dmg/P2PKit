//
//  ByteCountFormatter+Extensions.swift
//  P2PKit
//
//  Created by Henrik Panhans on 04.07.25.
//

import Foundation

extension ByteCountFormatter {

    static let `default`: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useKB, .useBytes]
        return formatter
    }()

}
