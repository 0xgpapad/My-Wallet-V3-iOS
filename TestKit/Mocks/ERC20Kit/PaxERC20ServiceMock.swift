//
//  PaxERC20ServiceMock.swift
//  ERC20KitTests
//
//  Created by Jack on 03/07/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import ERC20Kit
import EthereumKit
import Foundation
import PlatformKit
import RxSwift

class PaxERC20ServiceMock: ERC20ServiceAPI {
    func evaluate(amount cryptoValue: ERC20TokenValue<PaxToken>) -> Single<ERC20TransactionEvaluationResult<PaxToken>> {
        let addressString = MockEthereumWalletTestData.account
        let address = EthereumAddress(stringLiteral: addressString)
        let gasPrice = MockEthereumWalletTestData.Transaction.gasPrice
        let gasLimit = MockEthereumWalletTestData.Transaction.gasLimit
        // swiftlint:disable:next force_try
        let value = try! ERC20TokenValue<Token>(crypto: CryptoValue.paxZero)
        let proposal = ERC20TransactionProposal<PaxToken>(
            from: address,
            gasPrice: gasPrice,
            gasLimit: gasLimit,
            value: value
        )
        return Single.just(.valid(proposal))
    }

    func transfer(to: EthereumAddress, amount cryptoValue: ERC20TokenValue<PaxToken>) -> Single<EthereumTransactionCandidate> {
        let candidate = EthereumTransactionCandidateBuilder().build()!
        return Single.just(candidate)
    }
}
