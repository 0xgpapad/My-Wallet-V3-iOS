//
//  SupportedPairsService.swift
//  PlatformKit
//
//  Created by Daniel Huri on 23/01/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import RxRelay

public protocol SimpleBuySupportedPairsServiceAPI: class {

    /// Fetches `pairs` using the specified filter
    func fetchPairs(for option: SupportedPairsFilterOption) -> Single<SupportedPairs>
}

final class SupportedPairsService: SimpleBuySupportedPairsServiceAPI {
    
    // MARK: - Injected
    
    private let client: SupportedPairsClientAPI
    
    // MARK: - Setup
    
    init(client: SupportedPairsClientAPI) {
        self.client = client
    }
    
    // MARK: - SimpleBuySupportedPairsServiceAPI
    
    public func fetchPairs(for option: SupportedPairsFilterOption) -> Single<SupportedPairs> {
        client.supportedPairs(with: option)
            .map { SupportedPairs(response: $0, filterOption: option) }
    }
}
