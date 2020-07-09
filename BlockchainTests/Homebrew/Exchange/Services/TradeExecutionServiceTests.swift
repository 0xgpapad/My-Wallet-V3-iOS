//
//  TradeExecutionServiceTests.swift
//  BlockchainTests
//
//  Created by Jack on 02/07/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import BitcoinKit
import EthereumKit
import PlatformKit
import RxSwift
import StellarKit
import XCTest

@testable import Blockchain

class TradeExecutionServiceTests: XCTestCase {
    
    var wallet: MockLegacyEthereumWallet!
    var dependencies: TradeExecutionServiceDependenciesMock!
    var subject: TradeExecutionService!

    override func setUp() {
        super.setUp()
        
        wallet = MockLegacyEthereumWallet()
        dependencies = TradeExecutionServiceDependenciesMock()
        subject = TradeExecutionService(
            wallet: wallet,
            dependencies: dependencies
        )
    }

    override func tearDown() {
        subject = nil
        wallet = nil
        dependencies = nil
        
        super.tearDown()
    }

    func test_prebuild_pax_order() {
        let expectation = self.expectation(description: "Should build a valid PAX trade")
        
        let conversion: Conversion = Fixtures.load(name: "conversion", in: Bundle(for: TradeExecutionServiceTests.self))!
        
        let addressString = MockEthereumWalletTestData.account
        
        let address = AssetAddressFactory.create(
            fromAddressString: addressString,
            assetType: .pax
        )
        
        let from = AssetAccount(
            index: 0,
            address: address,
            balance: CryptoValue.paxFromMajor(string: "16.64306683")!,
            name: "My PAX Wallet"
        )
        
        let toAddressString = MockEthereumWalletTestData.account
        
        let toAddress = AssetAddressFactory.create(
            fromAddressString: toAddressString,
            assetType: .ethereum
        )

        let to = AssetAccount(
            index: 0,
            address: toAddress,
            balance: CryptoValue.etherFromMajor(string: "1.0")!,
            name: "My ETH Wallet"
        )
        
        let expectedOrderTransaction = OrderTransaction(
            orderIdentifier: Optional(""),
            destination: AssetAccount(
                index: 0,
                address: AssetAddressFactory.create(
                    fromAddressString: "0xe408d13921dbcd1cbcb69840e4da465ba07b7e5e",
                    assetType: .ethereum
                ),
                balance: CryptoValue.etherFromMajor(string: "1.0")!,
                name: "My ETH Wallet"
            ),
            from: AssetAccount(
                index: 0,
                address: AssetAddressFactory.create(
                    fromAddressString: "0xe408d13921dbcd1cbcb69840e4da465ba07b7e5e",
                    assetType: .pax
                ),
                balance: CryptoValue.paxFromMajor(string: "16.64306683")!,
                name: "My PAX Wallet"
            ),
            to: AssetAddressFactory.create(
                fromAddressString: "0xe408d13921dbcd1cbcb69840e4da465ba07b7e5e",
                assetType: .pax
            ),
            amountToSend: "6.87022901",
            amountToReceive: "0.02340873",
            fees: "0.000231"
        )
        
        let expectedConversion = Conversion(
            seqnum: 2,
            channel: "conversion",
            event: "updated",
            quote: Quote(
                time: Optional("2019-07-02T18:22:12.951Z"),
                pair: "PAX-ETH",
                fiatCurrency: "CAD",
                fix: Fix.baseInFiat,
                volume: "9.0",
                currencyRatio: CurrencyRatio(
                    base: FiatCrypto(
                        fiat: SymbolValue(
                            symbol: "CAD",
                            value: "9.00"
                        ),
                        crypto: SymbolValue(
                            symbol: "PAX",
                            value: "6.87022901"
                        )
                    ),
                    counter: FiatCrypto(
                        fiat: SymbolValue(
                            symbol: "CAD",
                            value: "8.86"
                        ),
                        crypto: SymbolValue(
                            symbol: "ETH",
                            value: "0.02340873"
                        )
                    ),
                    baseToFiatRate: "1.31",
                    baseToCounterRate: "0.00340727",
                    counterToBaseRate: "293.49009618",
                    counterToFiatRate: "378.57"
                )
            )
        )

        subject.prebuildOrder(
            with: conversion,
            from: from,
            to: to,
            success: { (orderTransaction, conv) in
                XCTAssertEqual(orderTransaction, expectedOrderTransaction)
                XCTAssertEqual(conv, expectedConversion)
                expectation.fulfill()
            },
            error: { error in
                print(error)
                XCTFail("This shouldn't fail")
            }
        )
        
        waitForExpectations(timeout: TimeInterval(100))
    }
}

extension OrderTransaction: Equatable {
    public static func == (lhs: OrderTransaction, rhs: OrderTransaction) -> Bool {
        lhs.amountToReceive == rhs.amountToReceive
            && lhs.amountToSend == rhs.amountToSend
            && lhs.destination == rhs.destination
            && lhs.fees == rhs.fees
            && lhs.from == rhs.from
            && lhs.orderIdentifier == rhs.orderIdentifier
            && lhs.to.publicKey == rhs.to.publicKey
    }
}
