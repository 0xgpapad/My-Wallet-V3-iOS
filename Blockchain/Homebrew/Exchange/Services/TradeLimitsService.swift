//
//  TradeLimitsService.swift
//  Blockchain
//
//  Created by Chris Arriola on 9/18/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import RxCocoa
import RxSwift
import PlatformKit

class TradeLimitsService: TradeLimitsAPI {

    private let disposables = CompositeDisposable()

    private let authenticationService: NabuAuthenticationService
    private let socketManager: SocketManager
    private var cachedLimits = BehaviorRelay<TradeLimits?>(value: nil)
    private var cachedLimitsTimer: Timer?
    private let clearCachedLimitsInterval: TimeInterval = 60
    private let communicator: NetworkCommunicatorAPI

    init(
        authenticationService: NabuAuthenticationService = NabuAuthenticationService.shared,
        socketManager: SocketManager = SocketManager.shared,
        communicator: NetworkCommunicatorAPI = NetworkCommunicator.shared
    ) {
        self.authenticationService = authenticationService
        self.socketManager = socketManager
        self.communicator = communicator
        self.cachedLimitsTimer = Timer.scheduledTimer(withTimeInterval: clearCachedLimitsInterval, repeats: true) { [weak self] _ in
            self?.clearCachedLimits()
        }
        self.cachedLimitsTimer?.tolerance = clearCachedLimitsInterval/10
        self.cachedLimitsTimer?.fire()
    }

    deinit {
        cachedLimitsTimer?.invalidate()
        cachedLimitsTimer = nil
        disposables.dispose()
    }

    enum TradeLimitsAPIError: Error {
        case generic
    }

    /// Initializes this TradeLimitsService so that the trade limits for the current
    /// user is pre-fetched and cached
    func initialize(withFiatCurrency currency: String) {
        let disposable = getTradeLimits(withFiatCurrency: currency, ignoringCache: false)
            .subscribeOn(MainScheduler.asyncInstance)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { _ in
                Logger.shared.debug("Successfully initialized TradeLimitsService.")
            }, onError: { error in
                Logger.shared.error("Failed to initialize TradeLimitsService: \(error)")
            })
        _ = disposables.insert(disposable)
    }

    func getTradeLimits(withFiatCurrency currency: String, withCompletion: @escaping ((Result<TradeLimits, Error>) -> Void)) {
        let disposable = getTradeLimits(withFiatCurrency: currency, ignoringCache: false)
            .subscribeOn(MainScheduler.asyncInstance)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { (payload) in
                withCompletion(.success(payload))
            }, onError: { error in
                withCompletion(.failure(error))
            })
        _ = disposables.insert(disposable)
    }

    func getTradeLimits(withFiatCurrency currency: String, ignoringCache: Bool) -> Single<TradeLimits> {
        return Single.deferred { [unowned self] in
            guard let cachedLimits = self.cachedLimits.value,
                cachedLimits.currency == currency,
                ignoringCache == false else {
                return self.getTradeLimitsNetwork(withFiatCurrency: currency)
            }
            return Single.just(cachedLimits)
        }.do(onSuccess: { [weak self] response in
            self?.cachedLimits.accept(response)
        })
    }

    // MARK: - Private

    private func getTradeLimitsNetwork(withFiatCurrency currency: String) -> Single<TradeLimits> {
        guard let baseURL = URL(
            string: BlockchainAPI.shared.retailCoreUrl
        ) else {
            return .error(TradeLimitsAPIError.generic)
        }

        guard let endpoint = URL.endpoint(
            baseURL,
            pathComponents: ["trades", "limits"],
            queryParameters: ["currency": currency]
        ) else {
            return .error(TradeLimitsAPIError.generic)
        }

        return authenticationService.getSessionToken().flatMap(weak: self) { (self, token) in
            return self.communicator.perform(
                request: NetworkRequest(
                    endpoint: endpoint,
                    method: .get,
                    headers: [HttpHeaderField.authorization: token.token]
                )
            )
        }
    }

    private func clearCachedLimits() {
        cachedLimits = BehaviorRelay<TradeLimits?>(value: nil)
    }
}
