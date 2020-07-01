//
//  SendSpendableBalanceInteractor.swift
//  Blockchain
//
//  Created by Daniel Huri on 07/08/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import PlatformKit
import RxRelay
import RxSwift

/// The interaction layer implementation for spendable balance on the send screen
final class SendSpendableBalanceInteractor: SendSpendableBalanceInteracting {
    
    // MARK: - Exposed Properties
    
    /// Streams the spendable balance
    var calculationState: Observable<FiatCryptoPairCalculationState> {
        calculationStateRelay.asObservable()
    }
    
    // MARK: - Private Properties
    
    private let calculationStateRelay = BehaviorRelay<FiatCryptoPairCalculationState>(value: .calculating)

    private let disposeBag = DisposeBag()

    // MARK: - Services
    
    private let balanceFetcher: AccountBalanceFetching
    private let feeInteractor: SendFeeInteracting
    private let exchangeService: PairExchangeServiceAPI
    
    // MARK: - Setup
    
    init(balanceFetcher: AccountBalanceFetching,
         feeInteractor: SendFeeInteracting,
         exchangeService: PairExchangeServiceAPI) {
        self.balanceFetcher = balanceFetcher
        self.feeInteractor = feeInteractor
        self.exchangeService = exchangeService
        
        let fee = feeInteractor.calculationState
            .compactMap { $0.value }
        let balance = balanceFetcher.balance.asObservable()
        let exchangeRate = exchangeService.fiatPrice
        
        // Calculate the balance and fetch the fiat price exchange,
        // while starting as `.calculating` state.
        // Combine-latest is the most reliable option to get stream of updated values
        // once all are calculated and any of them emits a new one.
        Observable
            .combineLatest(balance, exchangeRate, fee)
            .map { (balance, exchangeRate, fee) -> FiatCryptoPair in
                // Addition cannot fail as the fee and balance use the same underlying asset
                var spendableBalance = try balance - fee.crypto
                let zero = CryptoValue.zero(assetType: spendableBalance.currencyType)
                if try spendableBalance < zero {
                    spendableBalance = zero
                }
                return FiatCryptoPair(crypto: spendableBalance, exchangeRate: exchangeRate)
            }
            .map { .value($0) }
            .startWith(.calculating)
            .bindAndCatch(to: calculationStateRelay)
            .disposed(by: disposeBag)
    }
}
