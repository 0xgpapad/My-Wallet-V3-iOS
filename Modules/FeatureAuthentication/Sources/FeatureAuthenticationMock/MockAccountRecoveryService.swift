// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
@testable import FeatureAuthenticationDomain

final class MockAccountRecoveryService: AccountRecoveryServiceAPI {

    func resetVerificationStatus(
        guid: String,
        sharedKey: String
    ) -> AnyPublisher<Void, AccountRecoveryServiceError> {
        .just(())
    }

    func recoverUser(
        guid: String,
        sharedKey: String,
        userId: String,
        recoveryToken: String
    ) -> AnyPublisher<Void, AccountRecoveryServiceError> {
        .just(())
    }
}
