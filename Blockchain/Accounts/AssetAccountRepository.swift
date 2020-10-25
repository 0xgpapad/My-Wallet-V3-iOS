//
//  AssetAccountRepository.swift
//  Blockchain
//
//  Created by Chris Arriola on 9/13/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import BigInt
import DIKit
import ERC20Kit
import EthereumKit
import PlatformKit
import RxCocoa
import RxSwift
import StellarKit
import ToolKit

// TICKET: [IOS-2087] - Integrate PlatformKit Account Repositories and Deprecate AssetAccountRepository
/// A repository for `AssetAccount` objects
class AssetAccountRepository: AssetAccountRepositoryAPI {

    enum AssetAccountRepositoryError: Error {
        case unknown
        case noDefaultAccount
    }

    static let shared: AssetAccountRepositoryAPI = AssetAccountRepository()

    private let wallet: Wallet
    private let stellarServiceProvider: StellarServiceProvider
    private let paxAccountRepository: ERC20AssetAccountRepository<PaxToken>
    private let tetherAccountRepository: ERC20AssetAccountRepository<TetherToken>
    private let ethereumAccountRepository: EthereumAssetAccountRepository
    private let ethereumWalletService: EthereumWalletServiceAPI
    private let stellarAccountService: StellarAccountAPI
    private var cachedAccounts = BehaviorRelay<[AssetAccount]?>(value: nil)
    private let disposables = CompositeDisposable()
    private let enabledCurrenciesService: EnabledCurrenciesServiceAPI

    init(wallet: Wallet = WalletManager.shared.wallet,
         stellarServiceProvider: StellarServiceProvider = StellarServiceProvider.shared,
         ethereumAccountRepository: EthereumAssetAccountRepository = resolve(),
         paxAccountRepository: ERC20AssetAccountRepository<PaxToken> = resolve(),
         tetherAccountRepository: ERC20AssetAccountRepository<TetherToken> = resolve(),
         enabledCurrenciesService: EnabledCurrenciesServiceAPI = resolve(),
         ethereumWalletService: EthereumWalletServiceAPI = resolve()) {
        self.wallet = wallet
        self.enabledCurrenciesService = enabledCurrenciesService
        self.paxAccountRepository = paxAccountRepository
        self.tetherAccountRepository = tetherAccountRepository
        self.ethereumWalletService = ethereumWalletService
        self.stellarServiceProvider = stellarServiceProvider
        self.stellarAccountService = stellarServiceProvider.services.accounts
        self.ethereumAccountRepository = ethereumAccountRepository
    }

    deinit {
        disposables.dispose()
    }

    // MARK: Public Properties

    var accounts: Single<[AssetAccount]> {
        guard let value = cachedAccounts.value else {
            return fetchAccounts()
        }
        return .just(value)
    }

    var fetchETHHistoryIfNeeded: Single<Void> {
        ethereumWalletService.fetchHistoryIfNeeded
    }

    // MARK: Public Methods

    func accounts(for assetType: CryptoCurrency) -> Single<[AssetAccount]> {
        accounts(for: assetType, fromCache: true)
    }

    func accounts(for assetType: CryptoCurrency, fromCache: Bool) -> Single<[AssetAccount]> {
        guard wallet.isInitialized() else {
            return .just([])
        }

        switch assetType {
        case .algorand:
            return .just([])
        case .pax:
            return paxAccount(fromCache: fromCache)
        case .ethereum:
            return ethereumAccount(fromCache: fromCache)
        case .stellar:
            return stellarAccount(fromCache: fromCache)
        case .bitcoin,
             .bitcoinCash:
            return legacyAddress(assetType: assetType, fromCache: fromCache)
        case .tether:
            return tetherAccount(fromCache: fromCache)
        }
    }

    func nameOfAccountContaining(address: String, currencyType: CryptoCurrency) -> Single<String> {
        accounts
            .flatMap { output -> Single<String> in
                guard let result = output.first(where: { $0.address.publicKey == address && $0.balance.currencyType == currencyType }) else {
                    return .error(AssetAccountRepositoryError.unknown)
                }
                return .just(result.name)
            }
    }

    func fetchAccounts() -> Single<[AssetAccount]> {
        let observables: [Observable<[AssetAccount]>] = enabledCurrenciesService.allEnabledCryptoCurrencies.map {
            accounts(for: $0, fromCache: false).asObservable()
        }
        return Single.create { observer -> Disposable in
            let disposable = Observable.zip(observables)
                .subscribeOn(MainScheduler.asyncInstance)
                .map({ $0.flatMap({ $0 }) })
                .subscribe(onNext: { [weak self] output in
                    guard let self = self else { return }
                    self.cachedAccounts.accept(output)
                    observer(.success(output))
                })
            self.disposables.insertWithDiscardableResult(disposable)
            return Disposables.create()
        }
    }

    func defaultAccount(for assetType: CryptoCurrency) -> Single<AssetAccount> {
        switch assetType {
        case .algorand:
            return .error(AssetAccountRepositoryError.noDefaultAccount)
        case .stellar:
            guard let defaultAccount = stellarAccountService.currentAccount?.assetAccount else {
                return .error(AssetAccountRepositoryError.noDefaultAccount)
            }
            return .just(defaultAccount)
        case .bitcoin,
             .bitcoinCash:
            let index = wallet.getDefaultAccountIndex(for: assetType.legacy)
            guard let defaultAccount = AssetAccount.create(assetType: assetType, index: index, wallet: wallet) else {
                return .error(AssetAccountRepositoryError.noDefaultAccount)
            }
            return .just(defaultAccount)
        case .ethereum,
             .pax,
             .tether:
            return accounts(for: assetType, fromCache: false)
                .map { accounts in
                    guard let defaultAccount = accounts.first else {
                        throw AssetAccountRepositoryError.noDefaultAccount
                    }
                    return defaultAccount
                }
        }
    }

    // MARK: Private Methods

    private func stellarAccount(fromCache: Bool) -> Single<[AssetAccount]> {
        if fromCache {
            return cachedAccount(assetType: .stellar)
        } else {
            return stellarAccountService
                .currentStellarAccountAsSingle(fromCache: false)
                .map { account in
                    guard let account = account else {
                        return []
                    }
                    return [account.assetAccount]
                }
                .catchError { error -> Single<[AssetAccount]> in
                    /// Should Horizon go down or should we have an error when
                    /// retrieving the user's account details, we just want to return
                    /// a `Maybe.empty()`. If we return an error, the user will not be able
                    /// to see any of their available accounts in `Swap`.
                    guard error is StellarServiceError else {
                        return .error(error)
                    }
                    return .just([])
                }
        }
    }

    private func paxAccount(fromCache: Bool) -> Single<[AssetAccount]> {
        paxAccountRepository
            .currentAssetAccountDetails(fromCache: fromCache)
            .map { details -> AssetAccount in
                AssetAccount(
                    index: 0,
                    address: AssetAddressFactory.create(
                        fromAddressString: details.account.accountAddress,
                        assetType: .pax
                    ),
                    balance: details.balance,
                    name: details.account.name
                )
            }
            .map { [$0] }
    }

    private func tetherAccount(fromCache: Bool) -> Single<[AssetAccount]> {
        tetherAccountRepository
            .currentAssetAccountDetails(fromCache: fromCache)
            .map { details -> AssetAccount in
                AssetAccount(
                    index: 0,
                    address: AssetAddressFactory.create(
                        fromAddressString: details.account.accountAddress,
                        assetType: .tether
                    ),
                    balance: details.balance,
                    name: details.account.name
                )
            }
            .map { [$0] }
    }

    private func cachedAccount(assetType: CryptoCurrency) -> Single<[AssetAccount]> {
        accounts.map { result -> [AssetAccount] in
            result.filter { $0.address.cryptoCurrency == assetType }
        }
    }

    private func ethereumAccount(fromCache: Bool) -> Single<[AssetAccount]> {
        guard !fromCache else {
            return cachedAccount(assetType: .ethereum)
        }

        guard let ethereumAddress = self.wallet.getEtherAddress(), self.wallet.hasEthAccount() else {
            Logger.shared.debug("This wallet has no ethereum address.")
            return .just([])
        }

        let fallback = EthereumAssetAccount(
            walletIndex: 0,
            accountAddress: ethereumAddress,
            name: LocalizationConstants.myEtherWallet
        )
        let details = EthereumAssetAccountDetails(
            account: fallback,
            balance: .etherZero,
            nonce: 0
        )

        return ethereumAccountRepository.assetAccountDetails
            .catchErrorJustReturn(details)
            .map { details -> AssetAccount in
                AssetAccount(
                    index: 0,
                    address: AssetAddressFactory.create(
                        fromAddressString: details.account.accountAddress,
                        assetType: .ethereum
                    ),
                    balance: details.balance,
                    name: LocalizationConstants.myEtherWallet
                )
            }
            .map { [$0] }
    }

    // Handle BTC and BCH
    // TODO pull in legacy addresses.
    // TICKET: IOS-1290
    private func legacyAddress(assetType: CryptoCurrency, fromCache: Bool) -> Single<[AssetAccount]> {
        if fromCache {
            return cachedAccount(assetType: assetType)
        } else {
            let activeAccountsCount: Int32 = wallet.getActiveAccountsCount(assetType.legacy)
            /// Must have at least one address
            guard activeAccountsCount > 0 else {
                return .just([])
            }
            let result: [AssetAccount] = Array(0..<activeAccountsCount)
                .map { wallet.getIndexOfActiveAccount($0, assetType: assetType.legacy) }
                .compactMap { AssetAccount.create(assetType: assetType, index: $0, wallet: wallet) }
            return .just(result)
        }
    }
}

extension AssetAccount {

    /// Creates a new AssetAccount. This method only supports creating an AssetAccount for
    /// BTC or BCH. For ETH, use `defaultEthereumAccount`.
    fileprivate static func create(assetType: CryptoCurrency, index: Int32, wallet: Wallet) -> AssetAccount? {
        guard let address = wallet.getReceiveAddress(forAccount: index, assetType: assetType.legacy) else {
            return nil
        }
        let name = wallet.getLabelForAccount(index, assetType: assetType.legacy)
        let balanceFromWalletObject = wallet.getBalanceForAccount(index, assetType: assetType.legacy)
        let balance: CryptoValue
        if assetType == .bitcoin || assetType == .bitcoinCash {
            let balanceLong = balanceFromWalletObject as? CUnsignedLongLong ?? 0
            let balanceDecimal = Decimal(balanceLong) / Decimal(Constants.Conversions.satoshi)
            let balanceString = (balanceDecimal as NSDecimalNumber).description(withLocale: Locale.Posix)
            let balanceBigUInt = BigUInt(balanceString, decimals: assetType.maxDecimalPlaces) ?? 0
            let balanceBigInt = BigInt(balanceBigUInt)
            balance = CryptoValue.create(minor: balanceBigInt, currency: assetType)
        } else {
            let balanceString = balanceFromWalletObject as? String ?? "0"
            balance = CryptoValue.create(major: balanceString, currency: assetType) ?? CryptoValue.zero(currency: assetType)
        }
        return AssetAccount(
            index: index,
            address: AssetAddressFactory.create(fromAddressString: address, assetType: assetType),
            balance: balance,
            name: name ?? ""
        )
    }
}
