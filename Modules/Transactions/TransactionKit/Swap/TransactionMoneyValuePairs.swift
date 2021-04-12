//
//  TransactionMoneyValuePairs.swift
//  TransactionKit
//
//  Created by Alex McGregor on 11/12/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit

public struct TransactionMoneyValuePairs {
    /// Your `source` from a swap. Your `base` is `1: CryptoCurrency`
    /// and your quote is the current `FiatValue` for the given `CryptoCurrency`
    public let source: MoneyValuePair
    
    /// Your `destination` from a swap. Your `base` is `1: CryptoCurrency`
    /// and your quote is the current `FiatValue` for the given `CryptoCurrency`
    public let destination: MoneyValuePair
    
    public init(source: MoneyValuePair, destination: MoneyValuePair) {
        self.source = source
        self.destination = destination
    }
}
