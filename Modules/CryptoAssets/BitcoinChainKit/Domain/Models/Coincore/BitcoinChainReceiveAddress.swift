//
//  BitcoinChainReceiveAddress.swift
//  BitcoinChainKit
//
//  Created by Alex McGregor on 12/4/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import RxSwift
import TransactionKit

public struct BitcoinChainReceiveAddress<Token: BitcoinChainToken>: CryptoReceiveAddress, CryptoAssetQRMetadataProviding {
    
    public typealias TxCompleted = (TransactionResult) -> Completable
    
    public let address: String
    public let label: String
    public let onTxCompleted: TxCompleted
    public let index: Int32
    public var asset: CryptoCurrency {
        Token.coin.cryptoCurrency
    }
    
    public var metadata: CryptoAssetQRMetadata {
        switch Token.coin {
        case .bitcoin:
            return BitcoinURLPayload(address: address, amount: nil, includeScheme: true)
        case .bitcoinCash:
            return BitcoinCashURLPayload(address: address, amount: nil, includeScheme: true)
        }
    }
    
    public init(address: String,
                label: String,
                onTxCompleted: @escaping TxCompleted,
                index: Int32 = 0) {
        self.index = index
        self.address = address
        self.label = label
        self.onTxCompleted = onTxCompleted
    }
}
