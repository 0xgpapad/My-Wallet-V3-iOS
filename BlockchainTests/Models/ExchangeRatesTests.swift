//
//  ExchangeRatesTests.swift
//  BlockchainTests
//
//  Created by Jack on 01/07/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

@testable import Blockchain
import ERC20Kit
import PlatformKit
import XCTest

class ExchangeRatesTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func test_convert() {
        let balanceString = "16.64306683"
        let balanceCrypto = CryptoValue.paxFromMajor(string: balanceString)!
        let toCurrency = "CAD"
        let rates: ExchangeRates = Fixtures.load(name: "rates", in: Bundle(for: ExchangeRatesTests.self))!
        let conversion = rates.convert(balance: balanceCrypto, toCurrency: toCurrency)
        let expectedConversion = Decimal(string: "21.8024175473")!
        XCTAssertEqual(conversion.amount, expectedConversion)
    }
}
