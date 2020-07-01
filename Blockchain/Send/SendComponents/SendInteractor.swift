//
//  SendInteractor.swift
//  Blockchain
//
//  Created by Daniel Huri on 06/08/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import RxCocoa
import RxRelay
import RxSwift

/// The interactor that deals with the different logic, at the moment it is ether specific,
/// but in time we will add here all the supported assets logic.
final class SendInteractor: SendInteracting {
    
    // MARK: - Types
    
    /// Any error that involves the interaction layer
    enum InteractionError: Error {
        
        /// `Self` is unexpectedly nullified
        case nullifiedSelf
        
        /// The candidate is unexpectedly nullified
        case nullfiedCandidate
        
        /// The destination address is unexpectedly nullfied
        case nullfiedDestinationAddress
        
        /// The sent amount is unexpectedly nullified
        case nullifiedCryptoAmount
        
        /// The source account state is not `.available`
        case unexpectedSourceAccountState
    }
    
    /// The transaction candidate that is built just before sending the transaction
    struct TransactionCandidate {
        
        /// The destination address
        let address: String
        
        /// The crypto amount to be sent
        let amount: CryptoValue
    }
    
    // MARK: - Properties
    
    /// The asset type
    let asset: CryptoCurrency
    
    /// Streams the input state
    var inputState: Observable<SendInputState> {
        inputStateRelay.asObservable()
    }
    
    // MARK: - Services
    
    /// The interactor for the source acccount
    let sourceInteractor: SendSourceAccountInteracting
    
    /// The interactor for the destination account
    let destinationInteractor: SendDestinationAccountInteracting
    
    /// The interactor for the sent amount
    let amountInteractor: SendAmountInteracting
    
    /// The interactor for the spendable balance
    let spendableBalanceInteractor: SendSpendableBalanceInteracting
    
    /// The interactor for the fees account
    let feeInteractor: SendFeeInteracting
    
    /// Contains the needed services for executing the send
    private let services: SendServiceContaining
    
    /// The input state gathered from all the sub-interactors
    private let inputStateRelay = BehaviorRelay<SendInputState>(value: .empty)
    
    /// The transaction candidate
    private var transactionCandidate: TransactionCandidate!
    
    // MARK: - Accessors
    
    private let disposeBag = DisposeBag()
    
    // MARK: - Setup
    
    init(services: SendServiceContaining) {
        self.asset = services.asset
        self.services = services
    
        feeInteractor = SendFeeInteractor(
            feeService: services.fee,
            exchangeService: services.exchange
        )
        spendableBalanceInteractor = SendSpendableBalanceInteractor(
            balanceFetcher: services.balance,
            feeInteractor: feeInteractor,
            exchangeService: services.exchange
        )
        amountInteractor = SendAmountInteractor(
            asset: asset,
            spendableBalanceInteractor: spendableBalanceInteractor,
            feeInteractor: feeInteractor,
            exchangeService: services.exchange,
            fiatCurrencyService: services.fiatCurrency
        )
        sourceInteractor = SendSourceAccountInteractor(
            provider: services.sourceAccountProvider,
            stateService: services.sourceAccountState
        )
        destinationInteractor = SendDestinationAccountInteractor(
            asset: asset,
            exchangeAddressFetcher: services.exchangeAddressFetcher
        )

        // Flatten sub-interactors states into a one unified state (`SendInputState`).
        // Require each interactor to stream a valid state in order for the unified state
        // to be `.valid`
        Observable
            .combineLatest(amountInteractor.calculationState,
                           feeInteractor.calculationState,
                           sourceInteractor.state,
                           destinationInteractor.accountState,
                           amountInteractor.amountBalanceRatio)
            .map { (amountCalculationState, feeCalculationState, sourceAccountState, destinationAccountState, amountBalanceRatio) -> SendInputState in
                SendInputState(amountCalculationState: amountCalculationState, feeCalculationState: feeCalculationState, sourceAccountState: sourceAccountState, destinationAccountState: destinationAccountState, amountBalanceRatio: amountBalanceRatio)
            }
            .startWith(.empty)
            .bindAndCatch(to: inputStateRelay)
            .disposed(by: disposeBag)
    }
    
    /// Sets the destination address
    /// - Parameter address: the string representation of the address
    func set(address: String) {
        destinationInteractor.set(address: address)
    }
    
    /// Sets a crypto amount
    /// - Parameter cryptoAmount: the raw crypto amount represented as major. e.g "1.0" ~ 1
    func set(cryptoAmount: String) {
        amountInteractor.recalculateAmounts(fromCrypto: cryptoAmount)
    }
    
    /// Cleans the state of the interactor.
    /// Services should refresh their state: exchange rate and fee are refetched.
    func clean() {
        services.clean()
    }
    
    /// Prepares a candidate for sending. must be called before calling `func send()`,
    /// Since a candidate needs to be created and validated before the actual send.
    /// - Returns: A single that wraps `Void` to indicates a successful candidate creation,
    /// or a `Single.error(InteractionError)` to indicate the specific type of failure.
    /// Case of failure should be reached at this stage since all the input is assumed to
    /// be valid by now.
    func prepareForSending() -> Single<Void> {
        let sourceAccountStateValidation = sourceInteractor.state
            .take(1)
            .asSingle()
            .map { state -> Void in
                guard state == .available else { throw InteractionError.unexpectedSourceAccountState }
                return ()
            }
        
        let value = amountInteractor.calculationState
            .map { $0.value?.crypto }
            .take(1)
            .asSingle()
            .map { value -> CryptoValue in
                guard let value = value else { throw InteractionError.nullifiedCryptoAmount }
                return value
            }
        
        let address = destinationInteractor.accountState
            .map { $0.addressValue }
            .take(1)
            .asSingle()
            .map { value -> String in
                guard let value = value else { throw InteractionError.nullfiedDestinationAddress }
                return value
            }
        
        return Single
            .zip(address, value, sourceAccountStateValidation)
            .map { (address, value, _) -> TransactionCandidate in
                TransactionCandidate(address: address, amount: value)
            }
            .do(onSuccess: { [weak self] candidate in
                guard let self = self else {
                    throw InteractionError.nullifiedSelf
                }
                self.transactionCandidate = candidate
            })
            .mapToVoid()
    }

    /// Sends the transaction using the candidate generated by `func prepareForSending()`.
    /// Uses the execution service to send the transaction.
    /// If the execution is successful, the candidate is nullified and a Single<Void> is returned.
    /// - Returns: A single that wraps `Void` to indicates a successful send,
    /// or an `RxSwift` error to indicate failure.
    func send() -> Single<Void> {
        guard let transactionCandidate = transactionCandidate else {
            return Single.error(InteractionError.nullfiedCandidate)
        }
        return services.executor.send(
                value: transactionCandidate.amount,
                to: transactionCandidate.address
            )
            .do(onSuccess: { [weak self] _ in
                guard let self = self else { return }
                let asset = self.transactionCandidate.amount.currencyType
                self.services.bus.publish(
                    action: .sendCrypto,
                    extras: [WalletAction.ExtraKeys.assetType: asset]
                )
                self.transactionCandidate = nil
            })
    }
}
