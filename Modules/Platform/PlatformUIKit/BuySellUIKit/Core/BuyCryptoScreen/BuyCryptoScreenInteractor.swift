// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import DIKit
import PlatformKit
import RxRelay
import RxSwift
import ToolKit

final class BuyCryptoScreenInteractor: EnterAmountScreenInteractor {

    // MARK: - Types
    
    enum State {
        case inBounds(data: CandidateOrderDetails, upperLimit: FiatValue)
        case tooLow(min: FiatValue)
        case tooHigh(max: FiatValue)
        case empty(currency: FiatCurrency)
                
        var isValid: Bool {
            switch self {
            case .inBounds:
                return true
            default:
                return false
            }
        }
        
        var isEmpty: Bool {
            switch self {
            case .empty:
                return true
            default:
                return false
            }
        }
    }

    enum Effect {
        case failure
        case none
    }
    
    // MARK: - Properties

    /// Exposes a stream of the currently selected `CryptoCurrency` value
   override var selectedCurrencyType: Observable<CurrencyType> {
        cryptoCurrencySelectionService.selectedData.map { $0.cryptoCurrency.currency }.asObservable()
    }
    
    /// The state of the screen with associated data
    var state: Observable<State> {
        stateRelay.asObservable()
    }
    
    /// Whether the state of the screen is valid
    override var hasValidState: Observable<Bool> {
        state.map(\.isValid)
    }
    
    /// The (optional) data, in case the state's value is `inBounds`.
    /// `nil` otherwise.
    var candidateOrderDetails: Observable<CandidateOrderDetails?> {
        state
            .map { state in
                switch state {
                case .inBounds(data: let data, upperLimit: _):
                    return data
                default:
                    return nil
                }
            }
    }
    
    // MARK: - Output (readable)
            
    /// Calculation state of the supported pairs
    var pairsCalculationState: Observable<BuyCryptoSupportedPairsCalculationState> {
        pairsCalculationStateRelay.asObservable()
    }
                
    /// Suggested amounts, each represented a `Decimal value`
    var suggestedAmounts: Observable<[FiatValue]> {
        suggestedAmountsRelay.asObservable()
    }

    /// Streams a `KycState` indicating whether the user should complete KYC
    var currentKycState: Single<Result<KycState, Error>> {
        kycTiersService.fetchTiers()
            .map { $0.isTier2Approved }
            .mapToResult(successMap: { $0 ? .completed : .shouldComplete })
    }

    /// Streams a boolean indicating whether the user is eligible to Simple Buy
    var currentEligibilityState: Observable<Result<Bool, Error>> {
        eligibilityService
            .fetch()
            .mapToResult()
            .asObservable()
    }

    var paymentMethodTypes: Observable<[PaymentMethodType]> {
        Observable
            .combineLatest(
                paymentMethodTypesService.methodTypes,
                fiatCurrencyService.fiatCurrencyObservable
            )
            .map { payload in
                let (methods, fiatCurrency) = payload
                return methods.filterValidForBuy(currentWalletCurrency: fiatCurrency)
            }
            .catchErrorJustReturn([])
    }
    
    var preferredPaymentMethodType: Observable<PaymentMethodType?> {
        paymentMethodTypesService.preferredPaymentMethodType
    }

    /// An observable stream with a value of an effect.
    var effect: Observable<Effect> {
        effectRelay
            .asObservable()
    }
    
    // MARK: - Dependencies
        
    private let kycTiersService: KYCTiersServiceAPI
    private let suggestedAmountsService: SuggestedAmountsServiceAPI
    private let pairsService: SupportedPairsInteractorServiceAPI
    private let eligibilityService: EligibilityServiceAPI
    private let paymentMethodTypesService: PaymentMethodTypesServiceAPI
    private let orderCreationService: OrderCreationServiceAPI

    // MARK: - Accessors
    
    private let suggestedAmountsRelay = BehaviorRelay<[FiatValue]>(value: [])
    
    /// The fiat-crypto pairs
    private let pairsCalculationStateRelay = BehaviorRelay<BuyCryptoSupportedPairsCalculationState>(
        value: .invalid(.empty)
    )
    
    /// The state of the screen
    private let stateRelay = BehaviorRelay<State>(value: .empty(currency: FiatCurrency.default))

    /// A relay that streams an effect, such as a failure
    private let effectRelay = BehaviorRelay<Effect>(value: .none)

    private let disposeBag = DisposeBag()
    
    // MARK: - Setup
    
    init(kycTiersService: KYCTiersServiceAPI = resolve(),
         priceService: PriceServiceAPI = resolve(),
         paymentMethodTypesService: PaymentMethodTypesServiceAPI,
         fiatCurrencyService: FiatCurrencyServiceAPI = resolve(),
         cryptoCurrencySelectionService: CryptoCurrencySelectionServiceAPI,
         pairsService: SupportedPairsInteractorServiceAPI = resolve(),
         eligibilityService: EligibilityServiceAPI = resolve(),
         orderCreationService: OrderCreationServiceAPI = resolve(),
         suggestedAmountsService: SuggestedAmountsServiceAPI = resolve()) {
        self.kycTiersService = kycTiersService
        self.pairsService = pairsService
        self.suggestedAmountsService = suggestedAmountsService
        self.eligibilityService = eligibilityService
        self.paymentMethodTypesService = paymentMethodTypesService
        self.orderCreationService = orderCreationService
        super.init(
            priceService: priceService,
            fiatCurrencyService: fiatCurrencyService,
            cryptoCurrencySelectionService: cryptoCurrencySelectionService,
            initialActiveInput: .fiat
        )
    }
    
    // MARK: - Interactor
    
    override func didLoad() {
        
        let cryptoCurrencySelectionService = self.cryptoCurrencySelectionService
        let fiatCurrencyService = self.fiatCurrencyService
        
        amountTranslationInteractor.effect
            .map(\.toBuyCryptoInteractorEffect)
            .bindAndCatch(to: effectRelay)
            .disposed(by: disposeBag)
        
        state
            .flatMapLatest(weak: self) { (self, state) -> Observable<AmountTranslationInteractor.State> in
                Single
                    .zip(
                        self.amountTranslationInteractor.activeInputRelay.take(1).asSingle(),
                        cryptoCurrencySelectionService.cryptoCurrency
                    )
                    .flatMap(weak: self) { (self, values) -> Single<AmountTranslationInteractor.State> in
                        let activeInput = values.0
                        let currency = values.1
                        switch state {
                        case .tooHigh(max: let fiatValue), .tooLow(min: let fiatValue):
                            return self.priceService
                                .moneyValuePair(
                                    base: fiatValue,
                                    cryptoCurrency: currency,
                                    usesFiatAsBase: activeInput == .fiat
                                )
                                .map { pair -> AmountTranslationInteractor.State in
                                    switch state {
                                    case .tooHigh:
                                        return .maxLimitExceeded(pair.base)
                                    case .tooLow:
                                        return .minLimitExceeded(pair.base)
                                    case .empty:
                                        return .empty
                                    case .inBounds:
                                        return .inBounds
                                    }
                                }
                        case .empty:
                            return .just(.empty)
                        case .inBounds:
                            return .just(.inBounds)
                        }
                    }
                    .asObservable()
            }
            .do(onError: { [effectRelay] error in
                if effectRelay.value == .none {
                    effectRelay.accept(.failure)
                }
            })
            .catchError { error -> Observable<AmountTranslationInteractor.State> in
                .just(
                    AmountTranslationInteractor.State.error(
                        message: error.localizedDescription
                    )
                )
            }
            .bindAndCatch(to: amountTranslationInteractor.stateRelay)
            .disposed(by: disposeBag)
        
        suggestedAmountsService.calculationState
            .compactMap { $0.value }
            .bindAndCatch(to: suggestedAmountsRelay)
            .disposed(by: disposeBag)
        
        pairsService.fetch()
            .map { .value($0) }
            .catchErrorJustReturn(.invalid(.valueCouldNotBeCalculated))
            .startWith(.invalid(.empty))
            .bindAndCatch(to: pairsCalculationStateRelay)
            .disposed(by: disposeBag)
        
        let pairs = pairsCalculationState
            .compactMap { $0.value }
        
        let pairForCryptoCurrency = Observable
            .combineLatest(
                pairs,
                cryptoCurrencySelectionService.selectedData
            )
            .map { (pairs, item) -> SupportedPairs.Pair? in
                pairs.pairs(per: item.cryptoCurrency).first
            }
        
        let preferredPaymentMethod = self.preferredPaymentMethodType
            .compactMap { $0 }
        
        Observable
            .combineLatest(
                preferredPaymentMethod,
                amountTranslationInteractor.fiatAmount.compactMap { $0.fiatValue },
                amountTranslationInteractor.cryptoAmount.compactMap { $0.cryptoValue },
                pairForCryptoCurrency,
                fiatCurrencyService.fiatCurrencyObservable
            )
            .map { (preferredPaymentMethod, fiat, crypto, pair, currency) -> State in
                
                /// There must be a pair to compare to before calculation begins
                guard let pair = pair else {
                    return .empty(currency: currency)
                }
                
                let minFiatValue = pair.minFiatValue
                let maxFiatValue: FiatValue
                let paymentMethodId: String?
                
                switch preferredPaymentMethod {
                case .card(let cardData):
                    maxFiatValue = cardData.topLimit
                    paymentMethodId = cardData.identifier
                case .account(let data):
                    let maxQuoteFiatValue = data.balance.quote.fiatValue!
                    // Quote must be a fiat value
                    if try maxQuoteFiatValue < data.topLimit {
                        maxFiatValue = maxQuoteFiatValue
                    } else {
                        maxFiatValue = data.topLimit
                    }
                    paymentMethodId = nil
                case .suggested(let method):
                    guard method.max.currency == pair.maxFiatValue.currency else {
                        return .empty(currency: currency)
                    }
                    maxFiatValue = try FiatValue.min(pair.maxFiatValue, method.max)
                    paymentMethodId = nil
                case .linkedBank(let data):
                    maxFiatValue = data.topLimit
                    paymentMethodId = data.identifier
                }
                
                guard fiat.currencyType == minFiatValue.currencyType && fiat.currencyType == maxFiatValue.currencyType else {
                    return .empty(currency: currency)
                }
                
                if fiat.amount.isZero {
                    return .empty(currency: currency)
                } else if try fiat > maxFiatValue {
                    return .tooHigh(max: maxFiatValue)
                } else if try fiat < minFiatValue {
                    return .tooLow(min: minFiatValue)
                }
                let data: CandidateOrderDetails = .buy(
                    paymentMethod: preferredPaymentMethod,
                    fiatValue: fiat,
                    cryptoValue: crypto,
                    paymentMethodId: paymentMethodId
                )
                
                return .inBounds(data: data, upperLimit: pair.maxFiatValue)
            }
            // Handle possible errors: it is unlikely to get here unless
            // there was a connection / BE error
            .catchError { _ in
                fiatCurrencyService.fiatCurrencyObservable
                    .take(1)
                    .map { .empty(currency: $0) }
            }
            .bindAndCatch(to: stateRelay)
            .disposed(by: disposeBag)
        
        suggestedAmountsService.refresh()
    }

    // MARK: - Actions
    
    func createOrder(from candidate: CandidateOrderDetails) -> Single<CheckoutData> {
        orderCreationService.create(using: candidate)
    }
}

extension SelectionItemViewModel {

    var cryptoCurrency: CryptoCurrency {
        CryptoCurrency(code: id)!
    }
}

extension AmountTranslationInteractor.Effect {
    var toBuyCryptoInteractorEffect: BuyCryptoScreenInteractor.Effect {
        switch self {
        case .failure:
            return .failure
        case .none:
            return .none
        }
    }
}
