// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import PlatformKit

public struct BitcoinCashTransactionFee: TransactionFee, Decodable {

    public static var cryptoType: HasPathComponent = CryptoCurrency.bitcoinCash
    public static let `default` = BitcoinCashTransactionFee(
        limits: BitcoinCashTransactionFee.defaultLimits,
        regular: 5,
        priority: 11
    )
    public static let defaultLimits = TransactionFeeLimits(min: 2, max: 16)

    public var limits: TransactionFeeLimits
    public var regular: CryptoValue
    public var priority: CryptoValue

    enum CodingKeys: String, CodingKey {
        case regular
        case priority
        case limits
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let regularFee = try values.decode(Int.self, forKey: .regular)
        let priorityFee = try values.decode(Int.self, forKey: .priority)
        regular = CryptoValue.bitcoinCash(satoshis: regularFee)
        priority = CryptoValue.bitcoinCash(satoshis: priorityFee)
        limits = try values.decode(TransactionFeeLimits.self, forKey: .limits)
    }

    init(limits: TransactionFeeLimits, regular: Int, priority: Int) {
        self.limits = limits
        self.regular = CryptoValue.bitcoinCash(satoshis: regular)
        self.priority = CryptoValue.bitcoinCash(satoshis: priority)
    }
}
