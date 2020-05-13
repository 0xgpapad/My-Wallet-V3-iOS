//
//  PriceInFiat.swift
//  Blockchain
//
//  Created by Chris Arriola on 10/22/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import NetworkKit

/// Model for a quoted price by the Service-Price endpoint in fiat for a single asset type.
public struct PriceInFiat: Decodable, Equatable {
    public let timestamp: Date
    public let price: Decimal
    public let volume24h: Decimal?
    
    public static func ==(lhs: PriceInFiat, rhs: PriceInFiat) -> Bool {
        lhs.timestamp == rhs.timestamp
            && lhs.price == rhs.price
            && lhs.volume24h == rhs.volume24h
    }
    
    public init(timestamp: Date, price: Decimal, volume24h: Decimal?) {
        self.timestamp = timestamp
        self.price = price
        self.volume24h = volume24h
    }

    public static let empty: PriceInFiat = PriceInFiat(timestamp: .distantPast, price: 0, volume24h: nil)

    public func toPriceInFiatValue(fiatCurrency: FiatCurrency) -> PriceInFiatValue {
        PriceInFiatValue.init(base: self, fiatCurrency: fiatCurrency)
    }
}
