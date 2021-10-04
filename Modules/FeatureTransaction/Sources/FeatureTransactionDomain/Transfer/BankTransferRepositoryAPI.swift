// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import NabuNetworkError
import PlatformKit

public protocol BankTransferRepositoryAPI {

    func startBankTransfer(
        id: String,
        amount: MoneyValue
    ) -> AnyPublisher<BankTranferPayment, NabuNetworkError>
}
