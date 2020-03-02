//
//  CryptoCurrency.swift
//  PlatformKit
//
//  Created by AlexM on 12/5/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

/// This is used to distinguish between different types of digital assets.
/// `PlatformKit` should be almost entirely `CryptoCurrency` agnostic however.
/// It's possible that we may move this along with the other `Balance` related
/// models to a separate framework called `BalanceKit`.
/// This should be used a replacement for `AssetType` which is currently defined
/// in the app target.
public enum CryptoCurrency: String, Codable, CaseIterable {
    case bitcoin = "BTC"
    case ethereum = "ETH"
    case bitcoinCash = "BCH"
    case stellar = "XLM"
    case pax = "PAX"
}

extension CryptoCurrency: CodingKey { }

extension CryptoCurrency {
    
    @available(*, deprecated, message: "Superseded by `name`")
    public var description: String {
        switch self {
        case .bitcoin:
            return "Bitcoin"
        case .bitcoinCash:
            return "Bitcoin Cash"
        case .ethereum:
            return "Ether"
        case .stellar:
            return "Stellar"
        case .pax:
            return "USD PAX"
        }
    }
    
    public var name: String {
        switch self {
        case .bitcoin:
            return "Bitcoin"
        case .bitcoinCash:
            return "Bitcoin Cash"
        case .ethereum:
            return "Ether"
        case .stellar:
            return "Stellar"
        case .pax:
            return "USD PAX"
        }
    }
    
    public var symbol: String {
        return rawValue
    }
    
    public var code: String {
        return rawValue
    }
    
    public var maxDecimalPlaces: Int {
        switch self {
        case .bitcoin:
            return 8
        case .ethereum:
            return 18
        case .bitcoinCash:
            return 8
        case .stellar:
            return 7
        case .pax:
            return 18
        }
    }
    
    public var maxDisplayableDecimalPlaces: Int {
        switch self {
        case .bitcoin:
            return 8
        case .ethereum:
            return 8
        case .bitcoinCash:
            return 8
        case .stellar:
            return 7
        case .pax:
            return 8
        }
    }
}
