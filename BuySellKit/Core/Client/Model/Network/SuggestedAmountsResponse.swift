//
//  SuggestedAmountsResponse.swift
//  PlatformKit
//
//  Created by Daniel Huri on 29/01/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import ToolKit

struct SuggestedAmountsResponse: Decodable {

    let amounts: [String: [String]]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let amounts = try container.decode([[String: [String]]].self)
        self.amounts = amounts
            .reduce(into: [String: [String]]()) { result, element in
                element.forEach { result[$0.key] = $0.value }
            }
    }
}
