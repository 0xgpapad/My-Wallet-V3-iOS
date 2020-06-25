//
//  EthereumWalletAccountRepositoryMock.swift
//  EthereumKitTests
//
//  Created by Jack on 10/05/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import BigInt
@testable import EthereumKit
import Foundation
import PlatformKit
import RxSwift
import web3swift

class EthereumWalletAccountRepositoryMock: EthereumWalletAccountRepositoryAPI {
    var keyPairValue = Maybe.just(MockEthereumWalletTestData.keyPair)
    var keyPair: PrimitiveSequence<MaybeTrait, EthereumKeyPair> {
        keyPairValue
    }
    
    static let ethereumWalletAccount = EthereumWalletAccount(
        index: 0,
        publicKey: "",
        label: "",
        archived: false
    )
    
    var defaultAccountValue: EthereumWalletAccount? = ethereumWalletAccount
    var defaultAccount: EthereumWalletAccount? {
        defaultAccountValue
    }
    
    var initializeMetadataMaybeValue = Maybe.just(ethereumWalletAccount)
    func initializeMetadataMaybe() -> Maybe<EthereumWalletAccount> {
        initializeMetadataMaybeValue
    }
    
    var accountsValue: [EthereumWalletAccount] = []
    func accounts() -> [EthereumWalletAccount] {
        accountsValue
    }
}

enum EthereumAPIClientMockError: Error {
    case mockError
}

class EthereumAPIClientMock: EthereumClientAPI {

    var transaction = Single<EthereumHistoricalTransactionResponse>.error(EthereumAPIClientMockError.mockError)
    func transaction(with hash: String) -> Single<EthereumHistoricalTransactionResponse> {
        transaction
    }

    var balanceDetailsValue = Single<BalanceDetailsResponse>.error(EthereumAPIClientMockError.mockError)
    func balanceDetails(from address: String) -> Single<BalanceDetailsResponse> {
        balanceDetailsValue
    }
    
    var latestBlockValue: Single<LatestBlockResponse> = Single.error(EthereumAPIClientMockError.mockError)
    var latestBlock: Single<LatestBlockResponse> {
        latestBlockValue
    }
    
    var lastTransactionsForAccount: String?
    var transactionsForAccountValue: Single<[EthereumHistoricalTransactionResponse]> = Single.just([])
    func transactions(for account: String) -> Single<[EthereumHistoricalTransactionResponse]> {
        lastTransactionsForAccount = account
        return transactionsForAccountValue
    }
    
    var lastPushedTransaction: EthereumTransactionFinalised?
    var pushTransactionValue = Single.just(EthereumPushTxResponse(txHash: "txHash"))
    func push(transaction: EthereumTransactionFinalised) -> Single<EthereumPushTxResponse> {
        lastPushedTransaction = transaction
        return pushTransactionValue
    }
}

class EthereumFeeServiceMock: EthereumFeeServiceAPI {
    
    var feesValue = Single.just(EthereumTransactionFee.default)
    var fees: Single<EthereumTransactionFee> {
        feesValue
    }
}