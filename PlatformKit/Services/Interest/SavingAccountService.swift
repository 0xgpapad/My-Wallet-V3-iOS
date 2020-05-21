//
//  InterestAccountService.swift
//  PlatformKit
//
//  Created by Daniel Huri on 18/05/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift

public protocol SavingAccountServiceAPI: AnyObject {
    func balance(for currency: CryptoCurrency) -> Single<SavingsAccountBalanceState>
    func rate(for currency: CryptoCurrency) -> Single<Double>
}

public class SavingAccountService: SavingAccountServiceAPI {

    // MARK: - Private Properties

    private let authenticationService: NabuAuthenticationServiceAPI
    private let client: SavingsAccountClientAPI

    // MARK: - Setup

    public init(client: SavingsAccountClientAPI = SavingsAccountClient(),
                authenticationService: NabuAuthenticationServiceAPI) {
        self.client = client
        self.authenticationService = authenticationService
    }

    // MARK: - Public Methods

    public func balance(for currency: CryptoCurrency) -> Single<SavingsAccountBalanceState> {
        authenticationService.tokenString
            .flatMap(weak: self) { (self, token) in
                self.client.balance(for: currency.rawValue, token: token)
                    .map { balance in
                        guard let accountBalance = SavingsAccountBalance(currency: currency, response: balance) else {
                            return .absent
                        }
                        return .present(accountBalance)
                    }
            }
            .catchErrorJustReturn(.absent)
    }
    
    public func rate(for currency: CryptoCurrency) -> Single<Double> {
        authenticationService.tokenString
            .flatMap(weak: self) { (self, token) in
                self.client.rate(for: currency.rawValue, token: token)
            }
            .map { $0.rate }
    }
}
