//
//  EthereumTransactionSendingServiceTests.swift
//  EthereumKitTests
//
//  Created by Jack on 30/04/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import BigInt
@testable import EthereumKit
@testable import PlatformKit
import RxSwift
import RxTest
import XCTest

class EthereumTransactionSendingServiceTests: XCTestCase {
    
    var scheduler: TestScheduler!
    var disposeBag: DisposeBag!
    
    var bridge: EthereumWalletBridgeMock!
    var client: EthereumAPIClientMock!
    var feeService: EthereumFeeServiceMock!
    
    var transactionBuilder: EthereumTransactionBuilder!
    var transactionSigner: EthereumTransactionSigner!
    var transactionEncoder: EthereumTransactionEncoder!
    
    var subject: EthereumTransactionSendingService!
    
    override func setUp() {
        super.setUp()
        
        scheduler = TestScheduler(initialClock: 0)
        disposeBag = DisposeBag()

        bridge = EthereumWalletBridgeMock()
        client = EthereumAPIClientMock()
        feeService = EthereumFeeServiceMock()
        
        transactionBuilder = EthereumTransactionBuilder.shared
        transactionSigner = EthereumTransactionSigner.shared
        transactionEncoder = EthereumTransactionEncoder.shared
        
        subject = EthereumTransactionSendingService(
            with: bridge,
            client: client,
            feeService: feeService,
            transactionBuilder: transactionBuilder,
            transactionSigner: transactionSigner,
            transactionEncoder: transactionEncoder
        )
    }
    
    override func tearDown() {
        scheduler = nil
        disposeBag = nil
        bridge = nil
        client = nil
        feeService = nil
        transactionBuilder = nil
        transactionSigner = nil
        transactionEncoder = nil
        subject = nil
        
        super.tearDown()
    }
    
    func test_send() {
        // Arrange
        let candidate = EthereumTransactionCandidateBuilder().build()!
        
        let expectedPublished = EthereumTransactionPublishedBuilder()
            .with(candidate: candidate)
            .build()!
        
        client.pushTransactionValue = Single.just(
            EthereumPushTxResponse(txHash: expectedPublished.transactionHash)
        )
        
        let keyPair = MockEthereumWalletTestData.keyPair
        
        let sendObservable: Observable<EthereumTransactionPublished> = subject
            .send(transaction: candidate, keyPair: keyPair)
            .asObservable()
        
        // Act
        let result: TestableObserver<EthereumTransactionPublished> = scheduler
            .start { sendObservable }
        
        // Assert
        let expectedEvents: [Recorded<Event<EthereumTransactionPublished>>] = Recorded.events(
            .next(
                200,
                expectedPublished
            ),
            .completed(200)
        )
        
        XCTAssertEqual(result.events, expectedEvents)
    }
}
