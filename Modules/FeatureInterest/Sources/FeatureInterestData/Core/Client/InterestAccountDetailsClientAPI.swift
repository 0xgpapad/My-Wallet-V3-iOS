// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import NabuNetworkError
import PlatformKit

protocol InterestAccountDetailsClientAPI: AnyObject {
    func fetchInterestAccountRateForCurrencyCode(
        _ currencyCode: String
    ) -> AnyPublisher<InterestAccountRateResponse, NabuNetworkError>
}
