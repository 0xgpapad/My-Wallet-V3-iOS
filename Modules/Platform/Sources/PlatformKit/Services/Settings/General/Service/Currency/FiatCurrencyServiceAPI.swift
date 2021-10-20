// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import RxSwift

public protocol FiatCurrencyPublisherAPI {
    var fiatCurrencyPublisher: AnyPublisher<FiatCurrency, Never> { get }
}

/// An API of a generic service which provides fiat currency - to be inherited by any other service.
public protocol FiatCurrencyServiceAPI: FiatCurrencyPublisherAPI, CurrencyServiceAPI {

    /// An `Observable` that streams `FiatCurrency` values
    var fiatCurrencyObservable: Observable<FiatCurrency> { get }

    /// A `Single` that streams
    var fiatCurrency: Single<FiatCurrency> { get }

    @available(*, deprecated, message: "Do not use this. Prefer reactively getting the currency")
    var legacyCurrency: FiatCurrency? { get }
}

extension FiatCurrencyServiceAPI {

    public var currencyObservable: Observable<Currency> {
        fiatCurrencyObservable.map { $0 as Currency }
    }

    public var currency: Single<Currency> {
        fiatCurrency.map { $0 as Currency }
    }
}
