//
//  CollectionExtensionsTests.swift
//  P2PKit
//
//  Created by Henrik Panhans on 13.05.25.
//

import Foundation
import Testing

@testable import P2PKit

@Suite("Collection Extensions Tests")
struct CollectionExtensionsTests {

    @Test
    func chunks() {
        let numbers = Array(1...10)
        let chunks = numbers.chunked(into: 3)
        #expect(chunks == [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10]])
    }

    @Test
    func chunksWithPerfectSize() {
        let numbers = Array(1...9)
        let chunks = numbers.chunked(into: 3)
        #expect(chunks == [[1, 2, 3], [4, 5, 6], [7, 8, 9]])
    }

}
