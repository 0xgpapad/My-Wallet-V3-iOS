//
//  EthereumTransaction.swift
//  EthereumKit
//
//  Created by kevinwu on 2/6/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import BigInt
import PlatformKit

public struct EthereumHistoricalTransaction: EthereumTransaction, HistoricalTransaction, Mineable {
    public typealias Address = EthereumAddress

    public enum State: String, CaseIterable {
        case confirmed = "CONFIRMED"
        case pending = "PENDING"
        case replaced = "REPLACED"
    }

    public var fromAddress: EthereumAddress
    public var toAddress: EthereumAddress
    public var identifier: String
    public var direction: Direction
    public var amount: String
    public var transactionHash: String
    public var createdAt: Date
    public var fee: CryptoValue?
    public var memo: String?
    public var confirmations: UInt
    public var state: State
    public var isConfirmed: Bool {
        confirmations == 12
    }
    
    public init(
        identifier: String,
        fromAddress: EthereumAddress,
        toAddress: EthereumAddress,
        direction: Direction,
        amount: String,
        transactionHash: String,
        createdAt: Date,
        fee: CryptoValue?,
        memo: String?,
        confirmations: UInt,
        state: State
    ) {
        self.identifier = identifier
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.direction = direction
        self.amount = amount
        self.transactionHash = transactionHash
        self.createdAt = createdAt
        self.fee = fee
        self.memo = memo
        self.confirmations = confirmations
        self.state = state
    }
    
    public init(response: EthereumHistoricalTransactionResponse,
                memo: String? = nil,
                accountAddress: String,
                latestBlock: Int) {
        self.identifier = response.hash
        self.fromAddress = EthereumAddress(stringLiteral: response.from)
        self.toAddress = EthereumAddress(stringLiteral: response.to)
        self.direction = EthereumHistoricalTransaction.direction(
            to: response.to,
            from: response.from,
            accountAddress: accountAddress
        )
        self.amount = EthereumHistoricalTransaction.amount(value: response.value)
        self.transactionHash = response.hash
        self.createdAt = response.createdAt
        self.fee = EthereumHistoricalTransaction.fee(
            gasPrice: response.gasPrice,
            gasUsed: response.gasUsed
        )
        self.memo = memo
        self.confirmations = EthereumHistoricalTransaction.confirmations(
            latestBlock: latestBlock,
            blockNumber: response.blockNumber
        )
        self.state = response.state.transactionState
    }
    
    private static func created(timestamp: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
    
    private static func amount(value: String) -> String {
        guard
            let crypto = CryptoValue.etherFromWei(string: value),
            let ethereum = try? EthereumValue(crypto: crypto)
        else {
            return "0"
        }
        return ethereum.toDisplayString(includeSymbol: false, locale: Locale.current)
    }
    
    private static func direction(to: String, from: String, accountAddress: String) -> Direction {
        let incoming = to.lowercased() == accountAddress.lowercased()
        let outgoing = from.lowercased() == accountAddress.lowercased()
        if incoming && outgoing {
            return .transfer
        }
        if incoming {
            return .credit
        }
        return .debit
    }
    
    private static func fee(gasPrice: String, gasUsed: String?) -> CryptoValue {
        guard let gasUsed = gasUsed else {
            return CryptoValue.etherZero
        }
        let fee = BigInt(stringLiteral: gasPrice) * BigInt(stringLiteral: gasUsed)
        return CryptoValue.createFromMinorValue(fee, assetType: .ethereum)
    }
    
    private static func confirmations(latestBlock: Int, blockNumber: String?) -> UInt {
        guard let blockNumber: Int = blockNumber.flatMap({ Int($0) }) else {
            return 0
        }
        let confirmations = latestBlock - blockNumber + 1
        guard confirmations > 0 else {
            return 0
        }
        return UInt(confirmations)
    }
}

fileprivate extension EthereumHistoricalTransactionResponse.State {
    var transactionState: EthereumHistoricalTransaction.State {
        switch self {
        case .confirmed:
            return .confirmed
        case .pending:
            return .pending
        case .replaced:
            return .replaced
        }
    }
}

extension EthereumHistoricalTransaction: Comparable {
    public static func < (lhs: EthereumHistoricalTransaction, rhs: EthereumHistoricalTransaction) -> Bool {
        lhs.createdAt < rhs.createdAt
    }
}

extension EthereumHistoricalTransaction: Equatable {
    public static func == (lhs: EthereumHistoricalTransaction, rhs: EthereumHistoricalTransaction) -> Bool {
        lhs.identifier == rhs.identifier
    }
}
