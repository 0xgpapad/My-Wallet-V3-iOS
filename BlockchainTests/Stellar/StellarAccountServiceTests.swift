//
//  StellarAccountServiceTests.swift
//  BlockchainTests
//
//  Created by Chris Arriola on 10/26/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

@testable import Blockchain
import RxBlocking
import RxSwift
import StellarKit
import XCTest

private class MockLedgerService: StellarLedgerAPI {
    
    var fallbackBaseReserve: Decimal = 0
    var fallbackBaseFee: Decimal = 0
    
    var currentLedger: StellarLedger?

    var current: Observable<StellarLedger> {
        guard let ledger = currentLedger else {
            return Observable.just(StellarLedger.create())
        }
        return Observable.just(ledger)
    }
}

class StellarConfigurationServiceMock: StellarConfigurationAPI {
    var configuration: Single<StellarConfiguration> = Single.just(StellarConfiguration.Stellar.test)
}

class StellarAccountServiceTests: XCTestCase {

    private var ledgerService: MockLedgerService!
    private var accountService: StellarAccountService!

    override func setUp() {
        super.setUp()
        ledgerService = MockLedgerService()
        
        accountService = StellarAccountService(
            configurationService: StellarConfigurationServiceMock(),
            ledgerService: ledgerService,
            repository: StellarWalletAccountRepository(with: MockStellarBridge())
        )
    }

    /// Funding account should fail if amount < 2 * baseReserve
    func testFundAccountFailsForSmallAmount() {
        ledgerService.currentLedger = StellarLedger.create(baseReserveInStroops: 10000000)
        let exp = expectation(description: "amountTooLow error should be thrown.")
        _ = accountService.fundAccount(
            "account ID",
            amount: 0.01,
            sourceKeyPair: StellarKeyPair(accountID: "account", secret: "secret")
        ).subscribe(onError: { error in
            if let stellarError = error as? StellarFundsError, stellarError == .insufficientFundsForNewAccount {
                exp.fulfill()
            }
        })
        wait(for: [exp], timeout: 0.1)
    }
}

fileprivate extension StellarLedger {
    static func create(baseReserveInStroops: Int? = nil) -> StellarLedger {
        StellarLedger(
            identifier: "",
            token: "",
            sequence: 0,
            transactionCount: 0,
            operationCount: 0,
            closedAt: Date(),
            totalCoins: "",
            baseFeeInStroops: nil,
            baseReserveInStroops: baseReserveInStroops
        )
    }
}
