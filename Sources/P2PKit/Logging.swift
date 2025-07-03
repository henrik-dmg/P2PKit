//
//  Logging.swift
//  P2PKit
//
//  Created by Henrik Panhans on 07.04.25.
//

import Logging

extension Logger {

    static func multipeer(_ subCategory: String) -> Logger {
        Logger(label: "multipeer-\(subCategory)")
    }
    static func bluetooth(_ subCategory: String) -> Logger {
        Logger(label: "bluetooth-\(subCategory)")
    }
    static func bonjour(_ subCategory: String) -> Logger {
        Logger(label: "bonjour-\(subCategory)")
    }

}
