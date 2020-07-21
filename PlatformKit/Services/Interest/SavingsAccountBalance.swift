//
//  SavingsAccount.swift
//  PlatformKit
//
//  Created by Daniel Huri on 18/05/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

public struct CustodialAccountBalance: Equatable {

    let available: MoneyValue

    init?(currency: CryptoCurrency, response: SavingsAccountBalanceResponse.Details) {
        guard let balance = response.balance else { return nil }
        let available = CryptoValue(minor: balance, cryptoCurrency: currency) ?? .zero(currency: currency)
        self.available = available.moneyValue
    }
    
    init(currency: CurrencyType, response: CustodialBalanceResponse.Balance) {
        self.available = (try? MoneyValue(minor: response.available, currency: currency.code)) ?? .zero(currency)
    }
}
