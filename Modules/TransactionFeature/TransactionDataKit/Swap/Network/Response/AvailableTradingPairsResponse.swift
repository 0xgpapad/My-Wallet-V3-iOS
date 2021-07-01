// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import TransactionKit

struct AvailableTradingPairsResponse: Decodable {

    let pairs: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        pairs = try container.decode([String].self)
    }
}
