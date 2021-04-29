// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Foundation
import NetworkKit
import PlatformKit

extension BlockchainAPI {

    /// Returns the URL for the specified address's asset information (number of transactions,
    /// total sent/received, etc.)
    ///
    /// - Parameter assetAddress: the `AssetAddress`
    /// - Returns: the URL for the `AssetAddress`
    func assetInfoURL(for assetAddress: AssetAddress) -> String? {
        switch assetAddress.cryptoCurrency {
        case .bitcoin:
            return "\(walletUrl)/address/\(assetAddress.publicKey)?format=json"
        case .bitcoinCash:
            return "\(walletUrl)/bch/multiaddr?active=\(assetAddress.publicKey)"
        default:
            return nil
        }
    }
}
