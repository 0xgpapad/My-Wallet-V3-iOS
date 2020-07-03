//
//  MarketsService.swift
//  Blockchain
//
//  Created by kevinwu on 8/22/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import NetworkKit
import PlatformKit
import RxCocoa
import RxSwift
import ToolKit

protocol ExchangeMarketsAPI {
    func setup()
    func authenticate(completion: @escaping () -> Void)

    /// Unsubscribes from receiving conversion updates for the currency pair `pair`
    ///
    /// - Parameter pair: the currency pair (e.g. "BTC-ETH")
    func unsubscribeToCurrencyPair(pair: String)

    /// Computes the fiat balance in `fiatCurrency` for the provided `assetAccount` balance.
    /// This method will return an Observable which reports different fiat balances as
    /// the exchange rate changes.
    ///
    /// - Parameters:
    ///   - assetAccount: the AssetAccount
    ///   - fiatCurrencyCode: the currency code to compute the balance in (e.g. "USD")
    /// - Returns: an Observable returning the fiat balance
    func fiatBalance(forCryptoValue cryptoValue: CryptoValue, fiatCurrencyCode: String) -> Observable<FiatValue>

    // TICKET: IOS-1663 - return exchange rates for pairs that are both servier and app
    // supported
    /// Returns the best exchange rates for all pairs currently supported by the server
    ///
    /// - Returns: an Observable emitting the best exchanges rates as they reported through the websocket
    func bestExchangeRates() -> Observable<ExchangeRates>

    var hasAuthenticated: Bool { get }
    var conversions: Observable<Conversion> { get }
    var errors: Observable<SocketError> { get }
    func updateConversion(model: MarketsModel)
}

// MarketsService provides information about crypto/fiat trading data via observables.
// Data can include volume, price, and conversion rates given a quantity, trading pair and
// designated base or counter.
// This class is intended to provide observables for both websockets and REST endpoints.
// Ideally the caller should not care whether websockets or REST is used
// The DataSource enum should default first to websockets, then to REST as fallback.
class MarketsService {

    private let restMessageSubject = PublishSubject<Conversion>()
    private let authentication: NabuServiceProviderAPI
    private let socketManager: SocketManager
    private let cachedExchangeRates = BehaviorRelay<ExchangeRates?>(value: nil)
    private let cachedTradingPairs = BehaviorRelay<ExchangeTradingPairs?>(value: nil)
    private let disposables = CompositeDisposable()

    private var socketMessageObservable: Observable<SocketMessage> {
        SocketManager.shared.webSocketMessageObservable
    }

    private var dataSource: DataSource = .socket

    var hasAuthenticated: Bool = false
    
    private let communicator: NetworkCommunicatorAPI
    
    init(
        authenticationService: NabuServiceProviderAPI = NabuServiceProvider.default,
        socketManager: SocketManager = SocketManager.shared,
        communicator: NetworkCommunicatorAPI = Network.Dependencies.retail.communicator
    ) {
        self.authentication = authenticationService
        self.socketManager = socketManager
        self.communicator = communicator
    }

    deinit {
        disposables.dispose()
    }
}

// MARK: - Setup
extension MarketsService {
    func setup() {
        socketManager.setupSocket(socketType: .exchange, url: URL(string: BlockchainAPI.shared.retailCoreSocketUrl)!)
    }
}

// MARK: - Data sourcing
private extension MarketsService {
    // Two ways of retrieving data.
    enum DataSource {
        case socket // Using websockets, which is the default dataSource
        case rest // Using REST endpoints, which is the fallback dataSource
    }
}

// MARK: - Public API
extension MarketsService: ExchangeMarketsAPI {
    
    // MARK: - Authentication
    func authenticate(completion: @escaping () -> Void) {
        switch dataSource {
        case .socket: do {
            subscribeToHeartBeat(completion: completion)
            authenticateSocket()
        }
        case .rest: Logger.shared.debug("use REST endpoint")
        }
    }

    // MARK: - Conversion
    var conversions: Observable<Conversion> {
        switch dataSource {
        case .socket:
            return socketMessageObservable.filter {
                $0.type == .exchange &&
                    $0.JSONMessage is Conversion
            }.map { message in
                message.JSONMessage as! Conversion
            }
        case .rest:
            return restMessageSubject.filter({ _ -> Bool in
                false
            })
        }
    }
    
    var errors: Observable<SocketError> {
        // TODO: handle REST
        // TICKET: IOS-1320
        return socketMessageObservable.filter {
            $0.type == .exchange &&
                $0.JSONMessage is SocketError
            }.map { message in
                message.JSONMessage as! SocketError
        }
    }

    private var exchangeRatesObservable: Observable<ExchangeRates> {
        // TODO: handle REST
        // TICKET: IOS-1320
        return socketMessageObservable.filter {
            $0.type == .exchange
        }.filter {
            $0.JSONMessage is ExchangeRates
        }.map {
            $0.JSONMessage as! ExchangeRates
        }.do(onNext: { [weak self] exchangeRates in
            self?.cachedExchangeRates.accept(exchangeRates)
        })
    }

    func exchangeRateAvailablePairs() -> Single<ExchangeTradingPairs> {
        guard let baseURL = URL(
            string: BlockchainAPI.shared.retailCoreUrl) else {
                return Single.error(NetworkError.generic(message: "Could not form retail core url"))
        }

        guard let endpoint = URL.endpoint(
            baseURL,
            pathComponents: ["markets", "bestrates", "pairs"],
            queryParameters: nil) else {
                return Single.error(NetworkError.generic(message: "Could not get endpoint"))
        }

        return self.communicator.perform(
            request: NetworkRequest(
                endpoint: endpoint,
                method: .get,
                authenticated: true
            )
        )
    }

    func bestExchangeRates() -> Observable<ExchangeRates> {

        // Send exchange_rates socket message - get exchange rates for all possible pairs
        sendBestExchangeRatesSocketMessage()

        // Return exchange rates observable and start with cached rates if available
        var exchangeRates = exchangeRatesObservable
        if let cachedExchangeRates = cachedExchangeRates.value {
            exchangeRates = exchangeRates.startWith(cachedExchangeRates)
        }
        return exchangeRates
    }

    private func sendBestExchangeRatesSocketMessage() {
        if let cachedTradingPairs = cachedTradingPairs.value {
            subscribeTo(pairs: cachedTradingPairs)
        } else {
            let availablePairsDisposable = exchangeRateAvailablePairs()
                .subscribeOn(MainScheduler.asyncInstance)
                .observeOn(MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] in
                    guard let this = self else { return }
                    this.cachedTradingPairs.accept($0)
                    this.subscribeTo(pairs: $0)
                }, onError: { error in
                    Logger.shared.error("Could not get trading pairs: \(error)")
                })
            _ = disposables.insert(availablePairsDisposable)
        }
    }

    private func subscribeTo(pairs: ExchangeTradingPairs) {
        let params = CurrencyPairsSubscribeParams(pairs: pairs.pairs)
        let subscribe = Subscription(channel: "exchange_rate", params: params)
        let message = SocketMessage(type: .exchange, JSONMessage: subscribe)
        SocketManager.shared.send(message: message)
    }

    func fiatBalance(forCryptoValue cryptoValue: CryptoValue, fiatCurrencyCode: String) -> Observable<FiatValue> {

        // Don't need to get exchange rates if the account balance is 0
        guard cryptoValue.amount != 0 else {
            return Observable.just(FiatValue.zero(currencyCode: fiatCurrencyCode))
        }

        return bestExchangeRates().map { rates in
            rates.convert(
                balance: cryptoValue,
                toCurrency: fiatCurrencyCode
            )
        }
    }

    func updateConversion(model: MarketsModel) {
        switch dataSource {
        case .socket:
            let params = ConversionSubscribeParams(
                type: "conversionSpecification",
                pair: model.pair.stringRepresentation,
                fiatCurrency: model.fiatCurrencyCode,
                fix: model.fix,
                volume: model.volume)
            let quote = Subscription(channel: "conversion", params: params)
            let message = SocketMessage(type: .exchange, JSONMessage: quote)
            SocketManager.shared.send(message: message)
        case .rest:
            Logger.shared.debug("Not yet implemented")
        }
    }

    func unsubscribeToCurrencyPair(pair: String) {
        guard dataSource == .socket else {
            Logger.shared.info("Unsubscribing to a currency pair is only necessary if the data source is WS.")
            return
        }
        let params = ConversionPairUnsubscribeParams(pair: pair)
        let unsubscribeMessage = Unsubscription(channel: "conversion", params: params)
        let socketMessage = SocketMessage(type: .exchange, JSONMessage: unsubscribeMessage)
        SocketManager.shared.send(message: socketMessage)
    }
}

// MARK: - Private API
private extension MarketsService {
    func subscribeToHeartBeat(completion: @escaping () -> Void) {
        let heartBeatDisposable = socketMessageObservable
            .filter { socketMessage in
                socketMessage.JSONMessage is HeartBeat
            }
            .take(1)
            .asSingle()
            .subscribe(onSuccess: { [weak self] _ in
                guard let this = self else { return }
                this.hasAuthenticated = true
                completion()
            })

        _ = disposables.insert(heartBeatDisposable)
    }

    func authenticateSocket() {
        let authenticationDisposable = authentication
            .authenticator
            .token
            .map { token -> Subscription<AuthSubscribeParams> in
                let params = AuthSubscribeParams(type: "auth", token: token)
                return Subscription(channel: "auth", params: params)
            }
            .map { message in
                SocketMessage(type: .exchange, JSONMessage: message)
            }
            .subscribe(onSuccess: { socketMessage in
                SocketManager.shared.send(message: socketMessage)
            })

        _ = disposables.insert(authenticationDisposable)
    }
}
