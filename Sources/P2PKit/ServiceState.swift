//
//  ServiceState.swift
//  P2PChat
//
//  Created by Henrik Panhans on 22.03.25.
//

public enum ServiceState {

    case active
    case inactive
    case error(any Error)

    public var isActive: Bool {
        switch self {
        case .active:
            return true
        default:
            return false
        }
    }

}

// MARK: - Equatable

extension ServiceState: Equatable {

    public static func == (lhs: ServiceState, rhs: ServiceState) -> Bool {
        switch (lhs, rhs) {
        case (.active, .active), (.inactive, .inactive):
            return true
        case let (.error(lhsError), .error(rhsError)):
            return "\(lhsError)" == "\(rhsError)"
        default:
            return false
        }
    }

}
