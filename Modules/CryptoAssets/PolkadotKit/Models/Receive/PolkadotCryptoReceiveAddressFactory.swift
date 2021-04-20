//
//  PolkadotCryptoReceiveAddressFactory.swift
//  AlgorandKit
//
//  Created by Cosmin-Ionut Baies on 19.04.2021.
//  Copyright © 2021 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import RxSwift

final class PolkadotCryptoReceiveAddressFactory: CryptoReceiveAddressFactory {
    
    func makeExternalAssetAddress(
        address: String,
        label: String,
        onTxCompleted: @escaping TxCompleted
    ) throws -> CryptoReceiveAddress {
        PolkadotReceiveAddress(address: address, label: label, onTxCompleted: onTxCompleted)
    }
}
