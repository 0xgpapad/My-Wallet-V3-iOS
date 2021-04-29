// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Foundation

/// Protocol definition for a delegate for accountinfo-related wallet callbacks
protocol WalletAccountInfoDelegate: class {

    /// Invoked when the account info has been retrieved
    func didGetAccountInfo()
}
