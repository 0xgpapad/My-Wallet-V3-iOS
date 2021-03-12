//
//  AlgorandAsset.swift
//  AlgorandKit
//
//  Created by Paulo on 14/08/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import PlatformKit
import RxSwift
import ToolKit

final class AlgorandAsset: CryptoAsset {

    let asset: CryptoCurrency = .algorand

    var defaultAccount: Single<SingleAccount> {
        .error(CryptoAssetError.noDefaultAccount)
    }

    func accountGroup(filter: AssetFilter) -> Single<AccountGroup> {
        switch filter {
        case .all:
            return allAccountsGroup
        case .custodial:
            return custodialGroup
        case .interest:
            return interestGroup
        case .nonCustodial:
            return nonCustodialGroup
        }
    }
    
    // MARK: - Private Properties
    
    private let exchangeAccountProvider: ExchangeAccountsProviderAPI
    private let internalFeatureFlag: InternalFeatureFlagServiceAPI
    
    // MARK: - Init
    
    init(exchangeAccountProvider: ExchangeAccountsProviderAPI = resolve(),
         internalFeatureFlag: InternalFeatureFlagServiceAPI = resolve()) {
        self.exchangeAccountProvider = exchangeAccountProvider
        self.internalFeatureFlag = internalFeatureFlag
   }

    func parse(address: String) -> Single<ReceiveAddress?> {
        unimplemented()
    }

    // MARK: - Helpers

    private var allAccountsGroup: Single<AccountGroup> {
        let asset = self.asset
        return Single.zip(nonCustodialGroup,
                          custodialGroup,
                          interestGroup,
                          exchangeGroup)
            .map { (nonCustodialGroup, custodialGroup, interestGroup, exchangeGroup) -> [SingleAccount] in
                    nonCustodialGroup.accounts +
                    custodialGroup.accounts +
                    interestGroup.accounts +
                    exchangeGroup.accounts
            }
            .map { accounts -> AccountGroup in
                CryptoAccountNonCustodialGroup(asset: asset, accounts: accounts)
            }
    }

    private var custodialGroup: Single<AccountGroup> {
        .just(CryptoAccountCustodialGroup(asset: asset, accounts: [CryptoTradingAccount(asset: asset)]))
    }

    private var interestGroup: Single<AccountGroup> {
        .just(CryptoAccountCustodialGroup(asset: asset, accounts: []))
    }
    
    private var exchangeGroup: Single<AccountGroup> {
        let asset = self.asset
        guard internalFeatureFlag.isEnabled(.nonCustodialSendP2) else {
            return .just(CryptoAccountCustodialGroup(asset: asset, accounts: []))
        }
        return exchangeAccountProvider
            .account(for: asset)
            .catchError { error in
                /// TODO: This shouldn't prevent users from seeing all accounts.
                /// Potentially return nil should this fail.
                guard let serviceError = error as? ExchangeAccountsNetworkError else {
                    throw error
                }
                switch serviceError {
                case .missingAccount:
                    return Single.just(nil)
                }
            }
            .map { account in
                guard let account = account else {
                    return CryptoAccountCustodialGroup(asset: asset, accounts: [])
                }
                return CryptoAccountCustodialGroup(asset: asset, accounts: [account])
            }
    }

    private var nonCustodialGroup: Single<AccountGroup> {
        .just(CryptoAccountNonCustodialGroup(asset: asset, accounts: []))
    }
}
