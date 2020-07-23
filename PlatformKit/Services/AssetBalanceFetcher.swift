//
//  AssetBalanceFetcher.swift
//  Blockchain
//
//  Created by Daniel Huri on 31/10/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import RxCocoa
import RxRelay
import RxSwift

public protocol AssetBalanceFetching {
        
    /// Non-Custodial balance service
    var wallet: AccountBalanceFetching { get }
    
    /// Custodial balance service
    var trading: CustodialAccountBalanceFetching { get }
    
    /// Interest balance service
    var savings: CustodialAccountBalanceFetching { get }
        
    /// The calculation state of the asset balance
    var calculationState: Observable<MoneyBalancePairsCalculationState> { get }
    
    /// Trigger a refresh on the balance and exchange rate
    func refresh()
}

public final class AssetBalanceFetcher: AssetBalanceFetching {
        
    // MARK: - Properties
    
    public let wallet: AccountBalanceFetching
    public let trading: CustodialAccountBalanceFetching
    public let savings: CustodialAccountBalanceFetching
    
    /// The balance
    public var calculationState: Observable<MoneyBalancePairsCalculationState> {
        _ = setup
        return calculationStateRelay.asObservable()
    }
    
    private let calculationStateRelay = BehaviorRelay<MoneyBalancePairsCalculationState>(value: .calculating)
    private let exchange: PairExchangeServiceAPI
    private let disposeBag = DisposeBag()
    
    private lazy var setup: Void = {
        Observable
            .combineLatest(
                wallet.balanceMoneyObservable,
                trading.fundsState,
                savings.fundsState,
                exchange.fiatPrice
            )
            .map { payload in
                let (walletBalance, trading, savings, exchangeRate) = payload
                let fiatPrice = exchangeRate.moneyValue
                
                let baseCurrencyType = walletBalance.currencyType
                let quoteCurrencyType = fiatPrice.currencyType

                switch baseCurrencyType {
                case .fiat:
                    switch trading {
                    case .present(let tradingBalance):
                        return MoneyValueBalancePairs(trading: try MoneyValuePair(base: tradingBalance, exchangeRate: fiatPrice))
                    case .absent:
                        return MoneyValueBalancePairs(baseCurrency: baseCurrencyType, quoteCurrency: quoteCurrencyType)
                    }
                case .crypto:
                    let tradingBalance = trading.balance ?? .zero(baseCurrencyType)
                    let savingBalance = savings.balance ?? .zero(baseCurrencyType)
                    return MoneyValueBalancePairs(
                        wallet: try MoneyValuePair(base: walletBalance, exchangeRate: fiatPrice),
                        trading: try MoneyValuePair(base: tradingBalance, exchangeRate: fiatPrice),
                        savings: try MoneyValuePair(base: savingBalance, exchangeRate: fiatPrice)
                    )
                }
            }
            .map { .value($0) }
            .startWith(.calculating)
            .catchErrorJustReturn(.calculating)
            .bindAndCatch(to: calculationStateRelay)
            .disposed(by: disposeBag)
    }()
    
    // MARK: - Setup
    
    public init(wallet: AccountBalanceFetching,
                trading: CustodialAccountBalanceFetching,
                savings: CustodialAccountBalanceFetching,
                exchange: PairExchangeServiceAPI) {
        self.trading = trading
        self.wallet = wallet
        self.savings = savings
        self.exchange = exchange
    }
    
    public func refresh() {
        wallet.balanceFetchTriggerRelay.accept(())
        trading.balanceFetchTriggerRelay.accept(())
        savings.balanceFetchTriggerRelay.accept(())
        exchange.fetchTriggerRelay.accept(())
    }
}
