//
//  Logging.swift
//  P2PKit
//
//  Created by Henrik Panhans on 07.04.25.
//

import OSLog

extension Logger {

    private static var subsystem: String {
        "dev.panhans.P2PKit"
    }

    static func multipeer(_ subCategory: String) -> Logger {
        Logger(subsystem: subsystem, category: "multipeer-\(subCategory)")
    }
    static func bluetooth(_ subCategory: String) -> Logger {
        Logger(subsystem: subsystem, category: "bluetooth-\(subCategory)")
    }
    static func bonjour(_ subCategory: String) -> Logger {
        Logger(subsystem: subsystem, category: "bonjour-\(subCategory)")
    }

}
