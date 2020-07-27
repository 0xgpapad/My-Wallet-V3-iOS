//
//  HomebrewExchangeService.swift
//  Blockchain
//
//  Created by Alex McGregor on 8/20/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import NetworkKit
import PlatformKit
import RxSwift

typealias ExchangeCompletion = ((Result<[ExchangeTradeCellModel], Error>) -> Void)

protocol HomebrewExchangeAPI {
    // Currently this filters out trades with an unsupported trading pair.
    func nextPage(fromTimestamp: Date, completion: @escaping ExchangeCompletion)
}

enum HomebrewExchangeServiceError: Error {
    case generic
}

class HomebrewExchangeService: HomebrewExchangeAPI {
    
    fileprivate var disposable: Disposable?
    
    private let communicator: NetworkCommunicatorAPI
    
    init(communicator: NetworkCommunicatorAPI = resolve(tag: DIKitContext.retail)) {
        self.communicator = communicator
    }
    
    deinit {
        disposable?.dispose()
    }

    func nextPage(fromTimestamp: Date, completion: @escaping ExchangeCompletion) {
        disposable = trades(before: fromTimestamp)
            .subscribeOn(MainScheduler.asyncInstance)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { (payload) in
                let result: [ExchangeTradeCellModel] = payload.filter { $0.pair != nil }
                completion(.success(result))
            }, onError: { error in
                completion(.failure(error))
            })
    }
    
    fileprivate func trades(before timestamp: Date) -> Single<[ExchangeTradeCellModel]> {
        guard let baseURL = URL(string: BlockchainAPI.shared.retailCoreUrl) else {
            return .error(HomebrewExchangeServiceError.generic)
        }
        let dateParameter = DateFormatter.iso8601Format.string(from: timestamp)
        let userFiatCurrency = BlockchainSettings.App.shared.fiatCurrencyCode
        guard let endpoint = URL.endpoint(
            baseURL,
            pathComponents: ["trades"],
            queryParameters: ["before": dateParameter, "userFiatCurrency": userFiatCurrency]
        ) else {
            return .error(HomebrewExchangeServiceError.generic)
        }
        
        return self.communicator.perform(
            request: NetworkRequest(
                endpoint: endpoint,
                method: .get,
                authenticated: true
            )
        )
    }
}
