//
//  FiatCurrencySelectionProvider.swift
//  PlatformUIKit
//
//  Created by Paulo on 01/06/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import RxSwift

public protocol FiatCurrencySelectionProvider {
    var currencies: Observable<[FiatCurrency]> { get }
}

public final class DefaultFiatCurrencySelectionProvider: FiatCurrencySelectionProvider {
    public let currencies: Observable<[FiatCurrency]>

    public init(availableCurrencies: [FiatCurrency] = FiatCurrency.supported) {
        currencies = .just(availableCurrencies)
    }
}
