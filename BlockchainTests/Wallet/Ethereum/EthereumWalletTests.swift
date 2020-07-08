//
//  EthereumWalletTests.swift
//  BlockchainTests
//
//  Created by Jack on 22/02/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

@testable import Blockchain
import ERC20Kit
import EthereumKit
import PlatformKit
import PlatformUIKit
import RxSwift
import RxTest
import XCTest

class EthereumWalletTests: XCTestCase {
    
    var scheduler: TestScheduler!
    var disposeBag: DisposeBag!
    
    var subject: EthereumWallet!
    var legacyWalletMock: MockLegacyEthereumWallet!

    override func setUp() {
        super.setUp()
        
        scheduler = TestScheduler(initialClock: 0)
        disposeBag = DisposeBag()
        
        legacyWalletMock = MockLegacyEthereumWallet()
        // Hack to make things compile
        subject = EthereumWallet(schedulerType: scheduler!, wallet: legacyWalletMock)
        _ = subject.walletLoaded().subscribeOn(scheduler)
    }

    override func tearDown() {
        legacyWalletMock = nil
        subject = nil
        super.tearDown()
    }
    
    func test_wallet_name() {
        // Arrange
        let expectedName = "My ETH Wallet"
        let nameObservable: Observable<String> = subject
            .name
            .asObservable()
        
        // Act
        let result: TestableObserver<String> = scheduler
            .start { nameObservable }
        
        // Assert
        let expectedEvents: [Recorded<Event<String>>] = Recorded.events(
            .next(
                200,
                expectedName
            ),
            .completed(200)
        )
        
        let expectedElement = expectedEvents[0].value.element
        XCTAssertEqual(expectedName, expectedElement)
        
        let resultElement = result.events[0].value.element
        XCTAssertEqual(resultElement, expectedElement)
    }

    func test_wallet_address() {
        // Arrange
        let expectedAddress = EthereumKit.EthereumAddress(stringLiteral: "address")
        let addressObservable: Observable<EthereumKit.EthereumAddress> = subject
            .address
            .asObservable()
        
        // Act
        let result: TestableObserver<EthereumKit.EthereumAddress> = scheduler
            .start { addressObservable }
        
        // Assert
        let expectedEvents: [Recorded<Event<EthereumKit.EthereumAddress>>] = Recorded.events(
            .next(
                200,
                expectedAddress
            ),
            .completed(200)
        )

        let expectedElement = expectedEvents[0].value.element
        XCTAssertEqual(expectedAddress, expectedElement)
        
        let resultElement = result.events[0].value.element
        XCTAssertEqual(resultElement, expectedElement)
    }
    
    func test_wallet_account() {
        // Arrange
        let expectedAccount = EthereumAssetAccount(
            walletIndex: 0,
            accountAddress: MockEthereumWalletTestData.account,
            name: "My ETH Wallet"
        )
        
        let accountObservable: Observable<EthereumAssetAccount> = subject
            .account
            .asObservable()
        
        // Act
        let result: TestableObserver<EthereumAssetAccount> = scheduler
            .start { accountObservable }
        
        // Assert
        let expectedEvents: [Recorded<Event<EthereumAssetAccount>>] = Recorded.events(
            .next(
                200,
                expectedAccount
            ),
            .completed(200)
        )
        
        XCTAssertEqual(result.events, expectedEvents)
    }
    
    func test_wallet_not_initialised() {
        // Arrange
        legacyWalletMock.ethereumAccountsCompletion = .failure(
            MockLegacyEthereumWallet.MockLegacyEthereumWalletError.notInitialized
        )
        
        let expectedAccount = EthereumAssetAccount(
            walletIndex: 0,
            accountAddress: MockEthereumWalletTestData.account,
            name: "My ETH Wallet"
        )
        
        let walletObservable: Observable<EthereumAssetAccount> = subject
            .account
            .asObservable()
        
        // Act
        let result: TestableObserver<EthereumAssetAccount> = scheduler
            .start { walletObservable }
        
        // Assert
        let expectedEvents: [Recorded<Event<EthereumAssetAccount>>] = Recorded.events(
            .error(200, EthereumWallet.EthereumWalletError.ethereumAccountsFailed)
        )
        
        XCTAssertEqual(result.events, expectedEvents)
    }
    
    func test_get_token_accounts() {
        // Arrange
        let paxTokenAccount = ERC20TokenAccount(
            label: "My PAX Wallet",
            contractAddress: PaxToken.contractAddress.publicKey,
            hasSeen: false,
            transactionNotes: [
                "transaction_hash": "memo"
            ]
        )
        let expectedTokenAccounts: [String: ERC20TokenAccount] = [ PaxToken.metadataKey: paxTokenAccount ]

        let tokenAccountsObservable: Observable<[String: ERC20TokenAccount]> = subject
            .erc20TokenAccounts
            .asObservable()

        // Act
        let result: TestableObserver<[String: ERC20TokenAccount]> = scheduler
            .start { tokenAccountsObservable }

        // Assert
        let expectedEvents: [Recorded<Event<[String: ERC20TokenAccount]>>] = Recorded.events(
            .next(
                200,
                expectedTokenAccounts
            ),
            .completed(200)
        )

        XCTAssertEqual(result.events, expectedEvents)
    }
    
    func test_save_token_accounts() {
        // Arrange
        let paxTokenAccount = ERC20TokenAccount(
            label: "My PAX Wallet",
            contractAddress: PaxToken.contractAddress.publicKey,
            hasSeen: false,
            transactionNotes: [
                "transaction_hash": "memo"
            ]
        )
        let tokenAccounts: [String: ERC20TokenAccount] = [ PaxToken.metadataKey: paxTokenAccount ]
        
        let saveTokenAccountsObservable = subject
            .save(erc20TokenAccounts: tokenAccounts)
            .asObservable()
        
        // Act
        let result: TestableObserver<Void> = scheduler
            .start { saveTokenAccountsObservable }
        
        // Assert
        guard result.events.count == 2, result.events.first?.value != nil, result.events.last!.value.isCompleted else {
            XCTFail("Saving should complete successfully")
            return
        }
        
        XCTAssertEqual(legacyWalletMock.lastSavedTokensJSONString, "{\"pax\":{\"label\":\"My PAX Wallet\",\"contract\":\"0x8E870D67F660D95d5be530380D0eC0bd388289E1\",\"has_seen\":false,\"tx_notes\":{\"transaction_hash\":\"memo\"}}}")
    }
    
    func test_get_transaction_memo_for_token_transaction_hash() {
        // Arrange
        let expectedMemo = "memo"
        
        let transactionHash = "transaction_hash"
        let tokenKey = PaxToken.metadataKey
        
        let memoObservable: Observable<String?> = subject
            .memo(for: transactionHash, tokenKey: tokenKey)
            .asObservable()
        
        // Act
        let result: TestableObserver<String?> = scheduler
            .start { memoObservable }
        
        // Assert
        let expectedEvents: [Recorded<Event<String?>>] = Recorded.events(
            .next(
                200,
                expectedMemo
            ),
            .completed(200)
        )
        
        XCTAssertEqual(result.events, expectedEvents)
    }
    
    func test_save_transaction_memo_for_token_transaction_hash() {
        // Arrange
        let memo = "memo"
        
        let transactionHash = "transactionHash"
        let tokenKey = PaxToken.metadataKey
        
        let saveTokenAccountsObservable = subject
            .save(
                transactionMemo: memo,
                for: transactionHash,
                tokenKey: tokenKey
            )
            .asObservable()
        
        // Act
        let result: TestableObserver<Void> = scheduler
            .start { saveTokenAccountsObservable }
        
        // Assert
        guard result.events.count == 2, result.events.first?.value != nil, result.events.last!.value.isCompleted else {
            XCTFail("Saving should complete successfully")
            return
        }
        
        XCTAssertEqual(legacyWalletMock.lastSavedTokensJSONString, "{\"pax\":{\"label\":\"My PAX Wallet\",\"contract\":\"0x8E870D67F660D95d5be530380D0eC0bd388289E1\",\"has_seen\":false,\"tx_notes\":{\"transactionHash\":\"memo\",\"transaction_hash\":\"memo\"}}}")
    }
}

extension ERC20TokenAccount: Equatable {
    public static func == (lhs: ERC20TokenAccount, rhs: ERC20TokenAccount) -> Bool {
        lhs.label == rhs.label
            && lhs.contractAddress == rhs.contractAddress
            && lhs.hasSeen == rhs.hasSeen
            && lhs.transactionNotes == rhs.transactionNotes
    }
}

extension EthereumHistoricalTransaction: Equatable {
    public static func == (lhs: EthereumHistoricalTransaction, rhs: EthereumHistoricalTransaction) -> Bool {
        lhs.amount == rhs.amount
            && lhs.confirmations == rhs.confirmations
            && Calendar(identifier: .gregorian).compare(lhs.createdAt, to: rhs.createdAt, toGranularity: Calendar.Component.nanosecond) == .orderedSame
            && lhs.direction == rhs.direction
            && lhs.fee == rhs.fee
            && lhs.fromAddress == rhs.fromAddress
            && lhs.memo == rhs.memo
            && lhs.toAddress == rhs.toAddress
            && lhs.transactionHash == rhs.transactionHash
    }
}
