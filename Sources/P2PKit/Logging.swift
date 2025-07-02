//
//  Logging.swift
//  P2PKit
//
//  Created by Henrik Panhans on 07.04.25.
//

import Logging

extension Logger {

    private static var subsystem: String {
        "dev.panhans.P2PKit"
    }

    static func multipeer(_ subCategory: String) -> Logger {
        Logger(label: subsystem + ".multipeer-\(subCategory)")
    }
    static func bluetooth(_ subCategory: String) -> Logger {
        Logger(label: subsystem + ".bluetooth-\(subCategory)")
    }
    static func bonjour(_ subCategory: String) -> Logger {
        Logger(label: subsystem + ".bonjour-\(subCategory)")
    }

}
