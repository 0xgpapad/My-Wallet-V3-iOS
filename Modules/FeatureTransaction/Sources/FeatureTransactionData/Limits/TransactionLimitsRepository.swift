// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import FeatureTransactionDomain
import NabuNetworkError
import PlatformKit

final class TransactionLimitsRepository: TransactionLimitsRepositoryAPI {

    // MARK: - Properties

    private let client: TransactionLimitsClientAPI

    // MARK: - Setup

    init(client: TransactionLimitsClientAPI) {
        self.client = client
    }

    // MARK: - TransactionLimitServiceAPI

    func fetchTradeLimits(
        sourceCurrency: CurrencyType,
        destinationCurrency: CurrencyType,
        product: TransactionLimitsProduct
    ) -> AnyPublisher<TradeLimits, NabuNetworkError> {
        client
            .fetchTradeLimits(
                currency: sourceCurrency,
                networkFee: destinationCurrency,
                product: product
            )
            .map(TradeLimits.init)
            .eraseToAnyPublisher()
    }

    func fetchCrossBorderLimits(
        source: LimitsAccount,
        destination: LimitsAccount,
        limitsCurrency: CurrencyType
    ) -> AnyPublisher<CrossBorderLimits, NabuNetworkError> {
        client
            .fetchCrossBorderLimits(
                source: source,
                destination: destination,
                limitsCurrency: limitsCurrency
            )
            .map(CrossBorderLimits.init)
            .eraseToAnyPublisher()
    }
}
