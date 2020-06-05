//
//  StellarActivityItemEventDetails.swift
//  StellarKit
//
//  Created by Paulo on 21/05/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit

public struct StellarActivityItemEventDetails {

    public let cryptoAmount: CryptoValue
    public let createdAt: Date
    public let from: String
    public let to: String
    public let fee: CryptoValue?
    public let memo: String?
    public let transactionHash: String

    init(transaction: StellarHistoricalTransaction) {
        transactionHash = transaction.transactionHash
        cryptoAmount = transaction.amount
        createdAt = transaction.createdAt
        from = transaction.fromAddress.publicKey
        to = transaction.toAddress.publicKey
        fee = transaction.fee
        memo = transaction.memo
    }
}
