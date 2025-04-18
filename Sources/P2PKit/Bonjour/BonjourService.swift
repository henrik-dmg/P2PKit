//
//  BonjourService.swift
//  P2PKit
//
//  Created by Henrik Panhans on 10.04.25.
//

public struct BonjourService: Service {

    // MARK: - Properties

    public let type: String

    // MARK: - Init

    public init(type: String) {
        self.type = type
    }

}
