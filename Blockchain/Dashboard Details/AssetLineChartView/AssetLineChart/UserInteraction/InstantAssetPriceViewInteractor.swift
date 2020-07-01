//
//  InstantAssetPriceViewInteractor.swift
//  Blockchain
//
//  Created by AlexM on 11/20/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import PlatformUIKit
import RxCocoa
import RxRelay
import RxSwift

/// `InstantAssetPriceViewInteractor` is an `AssetPriceViewInteracting`
/// that takes a `AssetLineChartUserInteracting`. This allows the view to be
/// updated with price selections as the user interacts with the `LineChartView`
final class InstantAssetPriceViewInteractor: AssetPriceViewInteracting {
    
    public typealias InteractionState = DashboardAsset.State.AssetPrice.Interaction
    
    // MARK: - Exposed Properties
    
    public var state: Observable<InteractionState> {
        stateRelay.asObservable()
            .observeOn(MainScheduler.instance)
    }
            
    // MARK: - Private Accessors
    
    private let stateRelay = BehaviorRelay<InteractionState>(value: .loading)
    private let disposeBag = DisposeBag()
    
    // MARK: - Setup
    
    public init(historicalPriceProvider: HistoricalFiatPriceServiceAPI,
                chartUserInteracting: AssetLineChartUserInteracting) {
        Observable
            .combineLatest(
                historicalPriceProvider.calculationState,
                chartUserInteracting.state
            )
            .map { tuple -> InteractionState in
                let calculationState = tuple.0
                let userInteractionState = tuple.1
                
                switch (calculationState, userInteractionState) {
                case (.calculating, _),
                     (.invalid, _):
                    return .loading
                case (.value(let result), .deselected):
                    let delta = result.historicalPrices.delta
                    let currency = result.historicalPrices.currency
                    let window = result.priceWindow
                    let currentPrice = result.currentFiatValue
                    let fiatChange = FiatValue.create(
                        amount: result.historicalPrices.fiatChange,
                        currency: result.currentFiatValue.currencyType
                    )
                    return .loaded(
                        next: .init(
                            time: window.time(for: currency),
                            fiatValue: currentPrice,
                            changePercentage: delta,
                            fiatChange: fiatChange
                        )
                    )
                case (.value(let result), .selected(let index)):
                    let historicalPrices = result.historicalPrices
                    let currentFiatValue = result.currentFiatValue
                    let prices = Array(historicalPrices.prices[0...min(index, historicalPrices.prices.count - 1)])
                    let fiatCurrency = currentFiatValue.currencyType
                    guard let selected = prices.last else { return .loading }
                    let priceInFiatValue = selected.toPriceInFiatValue(fiatCurrency: fiatCurrency)
                    let adjusted = HistoricalPriceSeries(currency: historicalPrices.currency, prices: prices)
                    
                    let fiatChange = FiatValue.create(
                        amount: adjusted.fiatChange,
                        currency: fiatCurrency
                    )

                    return .loaded(
                        next: .init(
                            time: .timestamp(selected.timestamp),
                            fiatValue: priceInFiatValue.priceInFiat,
                            changePercentage: adjusted.delta,
                            fiatChange: fiatChange
                        )
                    )
                }
        }
        .catchErrorJustReturn(.loading)
        .bindAndCatch(to: stateRelay)
        .disposed(by: disposeBag)
    }
}
