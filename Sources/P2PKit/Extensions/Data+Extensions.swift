//
//  Data+Extensions.swift
//  P2PKit
//
//  Created by Henrik Panhans on 05.05.25.
//

// Adapted to Collection from https://www.hackingwithswift.com/example-code/language/how-to-split-an-array-into-chunks
extension Collection where Index: Strideable {

    func chunked(into size: Index.Stride) -> [SubSequence] {
        stride(from: startIndex, to: endIndex, by: size).map { index in
            self[index..<Swift.min(index.advanced(by: size), endIndex)]
        }
    }

}
