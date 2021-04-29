// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import AnalyticsKit

public struct PaymentMethodRemovalData {
    public enum MethodType {
        case card
        case beneficiary(Beneficiary.AccountType)
    }
    public let id: String
    public let title: String
    public let description: String
    public let image: String
    public let event: AnalyticsEvents.SimpleBuy
    public let type: MethodType

    public init(id: String,
                title: String,
                description: String,
                image: String,
                event: AnalyticsEvents.SimpleBuy,
                type: MethodType) {
        self.id = id
        self.title = title
        self.description = description
        self.image = image
        self.event = event
        self.type = type
    }
}
