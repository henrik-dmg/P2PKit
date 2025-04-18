//
//  Identifier.swift
//  rator-households-devices
//
//  Created by Henrik Panhans on 14.11.24.
//

import Foundation

public struct Identifier<Value, Container>: RawRepresentable {

    public var id: Value

    public var rawValue: Value { id }

    public init(_ id: Value) {
        self.id = id
    }

    public init?(rawValue: Value) {
        self.id = rawValue
    }

}

extension Identifier: Codable where Value: Codable {

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.id = try container.decode(Value.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.id)
    }

}

extension Identifier: Hashable where Value: Hashable {}

extension Identifier: Identifiable where Value: Hashable {}

extension Identifier: Equatable where Value: Equatable {}

extension Identifier: Sendable where Value: Sendable {}

extension Identifier where Value == UUID {

    public var uuidString: String {
        rawValue.uuidString
    }

}

extension Identifier: ExpressibleByUnicodeScalarLiteral where Value: ExpressibleByStringLiteral {

}

extension Identifier: ExpressibleByExtendedGraphemeClusterLiteral where Value: ExpressibleByStringLiteral {

}

extension Identifier: ExpressibleByStringLiteral where Value: ExpressibleByStringLiteral {

    public init(stringLiteral value: Value.StringLiteralType) {
        self.id = .init(stringLiteral: value)
    }

}
