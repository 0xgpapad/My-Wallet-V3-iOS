// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import PlatformKit

public struct OrdersActivityResponse: Decodable {
    let items: [FiatActivityItemEvent]
}
