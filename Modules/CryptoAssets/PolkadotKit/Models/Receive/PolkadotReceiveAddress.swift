// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import PlatformKit
import RxSwift

struct PolkadotReceiveAddress: CryptoReceiveAddress, CryptoAssetQRMetadataProviding {
    
    let asset: CryptoCurrency = .polkadot
    let address: String
    let label: String
    let onTxCompleted: (TransactionResult) -> Completable
    
    var metadata: CryptoAssetQRMetadata {
        PolkadotURLPayload(address: address)
    }
    
    init(address: String, label: String, onTxCompleted: @escaping (TransactionResult) -> Completable) {
        self.address = address
        self.label = label
        self.onTxCompleted = onTxCompleted
    }
}
