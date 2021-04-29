// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Foundation

/// The balance ratio on the source account
enum AmountBalanceRatio {
    
    /// The sent amount + fee is exceeding spendable balance
    case aboveSpendableBalance
    
    /// The sent amount + fee is within spendable balance
    case withinSpendableBalance
}
