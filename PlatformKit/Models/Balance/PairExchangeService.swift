//
//  PairExchangeService.swift
//  Blockchain
//
//  Created by Daniel Huri on 10/08/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import RxRelay

public protocol PairExchangeServiceAPI: class {
    
    /// The current fiat exchange price.
    /// The implementer should implement this as a `.shared(replay: 1)`
    /// resource for efficiency among multiple clients.
    var fiatPrice: Observable<FiatValue> { get }
    
    /// A trigger that force the service to fetch the updated price.
    /// Handy to call on currency type and value changes
    var fetchTriggerRelay: PublishRelay<Void> { get }
}

public final class PairExchangeService: PairExchangeServiceAPI {
    
    // TODO: Network failure
    
    /// Fetches the fiat price, and shares its stream with other
    /// subscribers to keep external API usage count in check.
    /// Also handles currency code change
    public let fiatPrice: Observable<FiatValue>
    
    /// A trigger for a fetch
    public let fetchTriggerRelay = PublishRelay<Void>()
    
    // MARK: - Services
    
    /// The exchange service
    private let priceService: PriceServiceAPI
    
    /// The currency service
    private let currencyService: FiatCurrencySettingsServiceAPI
    
    /// The associated asset
    private let cryptoCurrency: CryptoCurrency
    
    // MARK: - Setup
    
    public init(cryptoCurrency: CryptoCurrency,
                priceService: PriceServiceAPI = PriceService(),
                currencyService: FiatCurrencySettingsServiceAPI) {
        self.cryptoCurrency = cryptoCurrency
        self.priceService = priceService
        self.currencyService = currencyService

        let scheduler = ConcurrentDispatchQueueScheduler(qos: .background)

        fiatPrice = Observable
            .combineLatest(currencyService.fiatCurrencyObservable, fetchTriggerRelay)
            .throttle(.milliseconds(100), scheduler: scheduler)
            .map { $0.0 }
            .subscribeOn(scheduler)
            .observeOn(scheduler)
            .flatMapLatest { fiatCurrency -> Observable<PriceInFiatValue> in
                priceService
                    .price(for: cryptoCurrency, in: fiatCurrency)
                    .asObservable()
            }
            .map { $0.priceInFiat }
            .distinctUntilChanged()
            .share(replay: 1)
    }
}
