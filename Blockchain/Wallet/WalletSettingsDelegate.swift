// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Foundation

/// Protocol definition for a delegate for settings-related wallet callbacks
@objc protocol WalletSettingsDelegate: class {
    
    /// Method invoked when the web view needs to be initialized
    func didChangeLocalCurrency()
}
