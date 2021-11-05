// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
@testable import PlatformKit

class TradingBalanceServiceAPIMock: TradingBalanceServiceAPI {
    var underlyingBalanceState: CustodialAccountBalanceState = .absent
    var underlyingBalanceStates: CustodialAccountBalanceStates = .absent

    var balances: AnyPublisher<CustodialAccountBalanceStates, Never> {
        .just(underlyingBalanceStates)
    }

    func balance(for currencyType: CurrencyType) -> AnyPublisher<CustodialAccountBalanceState, Never> {
        .just(underlyingBalanceState)
    }

    func fetchBalances() -> AnyPublisher<CustodialAccountBalanceStates, Never> {
        .just(underlyingBalanceStates)
    }
}
