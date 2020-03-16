//
//  SendAmountInteracting.swift
//  Blockchain
//
//  Created by Daniel Huri on 06/08/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import PlatformKit
import RxSwift

/// The interaction protocol for the amount component on the send screen
protocol SendAmountInteracting {
    
    /// The interacted asset
    var asset: CryptoCurrency { get }
    
    /// Indicates whether the sent amount is within / above the account spendable balance
    var amountBalanceRatio: Observable<AmountBalanceRatio> { get }
    
    /// The total value: amount + fee
    var total: Observable<FiatCryptoPair> { get }
    
    /// The amount calculation state
    var calculationState: Observable<FiatCryptoPairCalculationState> { get }
    
    /// Spendable balance interactor
    var spendableBalanceInteractor: SendSpendableBalanceInteracting { get }

    /// Recalculates the amounts from a crypto raw value (major)
    func recalculateAmounts(fromCrypto rawValue: String)
    
    /// Recalculates the amounts from a fiat raw value
    func recalculateAmounts(fromFiat rawValue: String)
}
