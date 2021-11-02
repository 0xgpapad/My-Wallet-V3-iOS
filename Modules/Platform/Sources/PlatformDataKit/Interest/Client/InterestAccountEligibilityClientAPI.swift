// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import NabuNetworkError

protocol InterestAccountEligibilityClientAPI: AnyObject {
    func fetchInterestEnabledCurrenciesResponse()
        -> AnyPublisher<InterestEnabledCurrenciesResponse, NabuNetworkError>

    func fetchInterestAccountEligibilityResponse()
        -> AnyPublisher<InterestEligibilityResponse, NabuNetworkError>
}
