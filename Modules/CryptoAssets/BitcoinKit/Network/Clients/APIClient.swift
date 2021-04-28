//
//  NetworkClient.swift
//  BitcoinKit
//
//  Created by Jack on 08/09/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import BitcoinChainKit
import DIKit
import NetworkKit
import PlatformKit
import RxSwift

protocol APIClientAPI {
    
    func multiAddress(for addresses: [XPub]) -> Single<BitcoinMultiAddressResponse>
    
    func balances(for addresses: [XPub]) -> Single<BitcoinBalanceResponse>
    
    func unspentOutputs(for addresses: [XPub]) -> Single<UnspentOutputsResponse>
}

final class APIClient: APIClientAPI {
    
    private let client: BitcoinChainKit.APIClientAPI
    
    // MARK: - Init

    init(client: BitcoinChainKit.APIClientAPI = resolve(tag: BitcoinChainCoin.bitcoin)) {
        self.client = client
    }
    
    // MARK: - APIClientAPI
    
    func unspentOutputs(for addresses: [XPub]) -> Single<UnspentOutputsResponse> {
        client.unspentOutputs(for: addresses)
    }
    
    func multiAddress(for addresses: [XPub]) -> Single<BitcoinMultiAddressResponse> {
        client.multiAddress(for: addresses)
    }
    
    func balances(for addresses: [XPub]) -> Single<BitcoinBalanceResponse> {
        client.balances(for: addresses)
    }
}
