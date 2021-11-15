// Copyright © Blockchain Luxembourg S.A. All rights reserved.

public struct WithdrawalFeeAndLimit {

    public let maxLimit: FiatValue
    public let minLimit: FiatValue
    public let fee: FiatValue

    public init(
        maxLimit: FiatValue,
        minLimit: FiatValue,
        fee: FiatValue
    ) {
        self.maxLimit = maxLimit
        self.minLimit = minLimit
        self.fee = fee
    }
}
