// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BigInt
import DIKit
import EthereumKit
import PlatformKit
import RxSwift
import ToolKit
import TransactionKit

final class ERC20OnChainTransactionEngine<Token: ERC20Token>: OnChainTransactionEngine {
    
    typealias AskForRefreshConfirmations = (Bool) -> Completable
    
    // MARK: - OnChainTransactionEngine

    var askForRefreshConfirmation: (AskForRefreshConfirmations)!
    
    var fiatExchangeRatePairs: Observable<TransactionMoneyValuePairs> {
        sourceExchangeRatePair
            .map { pair -> TransactionMoneyValuePairs in
                TransactionMoneyValuePairs(
                    source: pair,
                    destination: pair
                )
            }
            .asObservable()
    }
    
    var sourceAccount: BlockchainAccount!
    var transactionTarget: TransactionTarget!
    
    let requireSecondPassword: Bool

    // MARK: - Private Properties
    
    private let feeService: AnyCryptoFeeService<ERC20TransactionFee<Token>>
    private let fiatCurrencyService: FiatCurrencyServiceAPI
    private let ethereumWalletService: EthereumWalletServiceAPI
    private let priceService: PriceServiceAPI
    private let bridge: EthereumWalletBridgeAPI
    private let balanceFetching: CryptoAccountBalanceFetching
    private let erc20service: AnyERC20Service<Token>
    private let erc20AccountService: ERC20AccountService<Token>
    private var target: ERC20ReceiveAddress<Token> {
        transactionTarget as! ERC20ReceiveAddress<Token>
    }
    
    // MARK: - Init
    
    init(requireSecondPassword: Bool,
         balanceFetching: CryptoAccountBalanceFetching = { () -> CryptoAccountBalanceFetching in resolve(tag: CryptoCurrency.ethereum) }(),
         priceService: PriceServiceAPI = resolve(),
         fiatCurrencyService: FiatCurrencyServiceAPI = resolve(),
         feeService: AnyCryptoFeeService<ERC20TransactionFee<Token>> = resolve(),
         ethereumWalletService: EthereumWalletServiceAPI = resolve(),
         ethereumWalletBridgeAPI: EthereumWalletBridgeAPI = resolve(),
         erc20service: AnyERC20Service<Token> = resolve(),
         erc20AccountService: ERC20AccountService<Token> = resolve()) {
        self.balanceFetching = balanceFetching
        self.fiatCurrencyService = fiatCurrencyService
        self.feeService = feeService
        self.ethereumWalletService = ethereumWalletService
        self.requireSecondPassword = requireSecondPassword
        self.priceService = priceService
        self.bridge = ethereumWalletBridgeAPI
        self.erc20service = erc20service
        self.erc20AccountService = erc20AccountService
    }
    
    // MARK: - OnChainTransactionEngine
    
    func assertInputsValid() {
        defaultAssertInputsValid()
        precondition(sourceCryptoCurrency.isERC20)
    }
    
    func initializeTransaction() -> Single<PendingTransaction> {
        fiatCurrencyService
            .fiatCurrency
            .map { fiatCurrency -> PendingTransaction in
                .init(
                    amount: .zero(currency: Token.assetType),
                    available: .zero(currency: Token.assetType),
                    feeAmount: MoneyValue.zero(currency: .ethereum),
                    feeForFullAvailable: MoneyValue.zero(currency: .ethereum),
                    feeSelection: .init(
                        selectedLevel: .regular,
                        availableLevels: [.regular, .priority],
                        asset: .crypto(.ethereum)
                    ),
                    selectedFiatCurrency: fiatCurrency
                )
            }
    }
    
    func start(
        sourceAccount: CryptoAccount,
        transactionTarget: TransactionTarget,
        askForRefreshConfirmation: @escaping AskForRefreshConfirmations
    ) {
        self.sourceAccount = sourceAccount
        self.transactionTarget = transactionTarget
        self.askForRefreshConfirmation = askForRefreshConfirmation
    }
    
    func restart(transactionTarget: TransactionTarget, pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        defaultRestart(
            transactionTarget: transactionTarget,
            pendingTransaction: pendingTransaction
        )
    }
    
    func doBuildConfirmations(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        Single
            .zip(
                fiatAmountAndFees(from: pendingTransaction),
                makeFeeSelectionOption(pendingTransaction: pendingTransaction)
            )
            .map { (fiatAmountAndFees, feeSelectionOption) ->
                (amountInFiat: MoneyValue, feesInFiat: MoneyValue, feeSelectionOption: TransactionConfirmation.Model.FeeSelection) in
                let (amountInFiat, feesInFiat) = fiatAmountAndFees
                return (amountInFiat.moneyValue, feesInFiat.moneyValue, feeSelectionOption)
            }
            .map(weak: self) { (self, payload) -> [TransactionConfirmation] in
                [
                    .sendDestinationValue(.init(value: pendingTransaction.amount)),
                    .source(.init(value: self.sourceAccount.label)),
                    .destination(.init(value: self.target.label)),
                    .feeSelection(payload.feeSelectionOption),
                    .feedTotal(
                        .init(
                            amount: pendingTransaction.amount,
                            amountInFiat: payload.amountInFiat,
                            fee: pendingTransaction.feeAmount,
                            feeInFiat: payload.feesInFiat
                        )
                    )
                ]
            }
            .map { pendingTransaction.update(confirmations: $0) }
    }
    
    func update(amount: MoneyValue, pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        guard sourceAccount != nil else {
            return .just(pendingTransaction)
        }
        guard let crypto = amount.cryptoValue else {
            return .error(TransactionValidationFailure(state: .unknownError))
        }
        guard crypto.currencyType == Token.assetType else {
            return .error(TransactionValidationFailure(state: .unknownError))
        }
        return Single.zip(
            sourceAccount.actionableBalance,
            absoluteFee(with: pendingTransaction.feeLevel)
        )
        .map { (values) -> PendingTransaction in
            let (actionableBalance, fee) = values
            return pendingTransaction.update(
                amount: amount,
                available: actionableBalance,
                fee: fee.moneyValue,
                feeForFullAvailable: fee.moneyValue
            )
        }
    }
    
    func doOptionUpdateRequest(pendingTransaction: PendingTransaction, newConfirmation: TransactionConfirmation) -> Single<PendingTransaction> {
        switch newConfirmation {
        case .feeSelection(let value) where value.selectedLevel != pendingTransaction.feeLevel:
            return updateFeeSelection(
                pendingTransaction: pendingTransaction,
                newFeeLevel: value.selectedLevel,
                customFeeAmount: nil
            )
        default:
            return defaultDoOptionUpdateRequest(
                pendingTransaction: pendingTransaction,
                newConfirmation: newConfirmation
            )
        }
    }
    
    func validateAmount(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        validateAmounts(pendingTransaction: pendingTransaction)
            .andThen(validateSufficientFunds(pendingTransaction: pendingTransaction))
            .andThen(validateSufficientGas(pendingTransaction: pendingTransaction))
            .updateTxValidityCompletable(pendingTransaction: pendingTransaction)
    }
    
    func doValidateAll(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        validateAddresses()
            .andThen(validateAmounts(pendingTransaction: pendingTransaction))
            .andThen(validateSufficientFunds(pendingTransaction: pendingTransaction))
            .andThen(validateSufficientGas(pendingTransaction: pendingTransaction))
            .andThen(validateNoPendingTransaction())
            .updateTxValidityCompletable(pendingTransaction: pendingTransaction)
    }
    
    func execute(pendingTransaction: PendingTransaction, secondPassword: String) -> Single<TransactionResult> {
        guard let crypto = pendingTransaction.amount.cryptoValue else {
            return .error(TransactionValidationFailure(state: .unknownError))
        }
        guard let erc20value = try? ERC20TokenValue<Token>(crypto: crypto) else {
            return .error(TransactionValidationFailure(state: .unknownError))
        }
        return Single.just(target)
            .map(\.address)
            .flatMap(weak: self) { (self, address) -> Single<TransactionResult> in
                self.erc20service
                    .transfer(
                        to: EthereumAddress(stringLiteral: address),
                        amount: erc20value
                    )
                    .flatMap(weak: self) { (self, candidate) -> Single<EthereumTransactionPublished> in
                        self.ethereumWalletService.send(transaction: candidate)
                    }
                    .map(\.transactionHash)
                    .map { transactionHash in
                        .hashed(txHash: transactionHash, amount: pendingTransaction.amount)
                    }
            }
    }
    
    func startConfirmationsUpdate(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        .just(pendingTransaction)
    }
    
    // MARK: - Private Functions
    
    private func validateNoPendingTransaction() -> Completable {
        bridge
            .isWaitingOnTransaction
            .map { (isWaitingOnTransaction) -> Void in
                guard isWaitingOnTransaction == false else {
                    throw TransactionValidationFailure(state: .transactionInFlight)
                }
            }
            .asCompletable()
    }
    
    private func validateAmounts(pendingTransaction: PendingTransaction) -> Completable {
        Completable.fromCallable {
            if try pendingTransaction.amount <= CryptoValue.zero(currency: Token.assetType).moneyValue {
                throw TransactionValidationFailure(state: .invalidAmount)
            }
        }
    }

    private func validateSufficientFunds(pendingTransaction: PendingTransaction) -> Completable {
        guard sourceAccount != nil else {
            fatalError("sourceAccount should never be nil when this is called")
        }
        return sourceAccount
            .actionableBalance
            .map { actionableBalance -> Void in
                guard try pendingTransaction.amount <= actionableBalance else {
                    throw TransactionValidationFailure(state: .insufficientFunds)
                }
            }
            .asCompletable()
    }

    private func validateSufficientGas(pendingTransaction: PendingTransaction) -> Completable {
        Single
            .zip(
                ethereumAccountBalance,
                absoluteFee(with: pendingTransaction.feeLevel)
            )
            .map { (balance, absoluteFee) -> Void in
                guard try absoluteFee <= balance else {
                    throw TransactionValidationFailure(state: .insufficientGas)
                }
            }
            .asCompletable()
    }

    private func validateAddresses() -> Completable {
        erc20AccountService.isContract(address: target.address)
            .map { isContractAddress -> Bool in
                guard !isContractAddress else {
                    throw TransactionValidationFailure(state: .invalidAddress)
                }
                return isContractAddress
            }
            .asCompletable()
    }
    
    private func makeFeeSelectionOption(pendingTransaction: PendingTransaction) -> Single<TransactionConfirmation.Model.FeeSelection> {
        Single
            .just(pendingTransaction)
            .map(weak: self) { (self, pendingTransaction) -> FeeState in
                try self.getFeeState(pendingTransaction: pendingTransaction)
            }
            .map { (feeState) -> TransactionConfirmation.Model.FeeSelection in
                TransactionConfirmation.Model.FeeSelection(
                    feeState: feeState,
                    selectedLevel: pendingTransaction.feeLevel,
                    fee: pendingTransaction.feeAmount
                )
            }
    }
    
    private func fiatAmountAndFees(from pendingTransaction: PendingTransaction) -> Single<(amount: FiatValue, fees: FiatValue)> {
        Single.zip(
            sourceExchangeRatePair,
            .just(pendingTransaction.amount.cryptoValue ?? .zero(currency: Token.assetType)),
            .just(pendingTransaction.feeAmount.cryptoValue ?? .zero(currency: Token.assetType))
        )
        .map({ (quote: ($0.0.quote.fiatValue ?? .zero(currency: .USD)), amount: $0.1, fees: $0.2) })
        .map { (quote: (FiatValue), amount: CryptoValue, fees: CryptoValue) -> (FiatValue, FiatValue) in
            let fiatAmount = amount.convertToFiatValue(exchangeRate: quote)
            let fiatFees = fees.convertToFiatValue(exchangeRate: quote)
            return (fiatAmount, fiatFees)
        }
        .map { (amount: $0.0, fees: $0.1) }
    }

    private func absoluteFee(with feeLevel: FeeLevel) -> Single<CryptoValue> {
        feeService
            .fees
            .map(\.ethereumFee)
            .map { (fees: EthereumTransactionFee) -> CryptoValue in
                let level: EthereumTransactionFee.FeeLevel
                switch feeLevel {
                case .none:
                    fatalError("On chain ERC20 transactions should never have a 0 fee")
                case .priority,
                     .custom:
                    level = .priority
                case .regular:
                    level = .regular
                }
                return fees.absoluteFee(with: level, isContract: true)
            }
    }

    private var ethereumAccountBalance: Single<CryptoValue> {
        balanceFetching.balance
    }
    
    private var sourceExchangeRatePair: Single<MoneyValuePair> {
        fiatCurrencyService
            .fiatCurrency
            .flatMap(weak: self) { (self, fiatCurrency) -> Single<MoneyValuePair> in
                self.priceService
                    .price(for: self.sourceAsset, in: fiatCurrency)
                    .map(\.moneyValue)
                    .map { MoneyValuePair(base: .one(currency: self.sourceAsset), quote: $0) }
            }
    }
}
