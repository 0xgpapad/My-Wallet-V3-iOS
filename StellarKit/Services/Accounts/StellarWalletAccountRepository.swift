//
//  StellarWalletAccountRepository.swift
//  StellarKit
//
//  Created by Alex McGregor on 11/13/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import RxSwift
import PlatformKit

open class StellarWalletAccountRepository: WalletAccountRepositoryAPI, WalletAccountInitializer, KeyPairProviderAPI {
    public typealias Pair = StellarKeyPair
    public typealias WalletAccount = StellarWalletAccount
    public typealias Bridge = StellarWalletBridgeAPI & MnemonicAccessAPI
    
    fileprivate let bridge: Bridge
    fileprivate let deriver: StellarKeyPairDeriver = StellarKeyPairDeriver()
    
    public init(with bridge: Bridge) {
        self.bridge = bridge
    }
    
    public func initializeMetadataMaybe() -> Maybe<WalletAccount> {
        return loadDefaultAccount().ifEmpty(
            switchTo: createAndSaveStellarAccount()
        )
    }
    
    /// The default `StellarWallet`, will be nil if it has not yet been initialized
    open var defaultAccount: WalletAccount? {
        return accounts().first
    }
    
    open func accounts() -> [WalletAccount] {
        return bridge.stellarWallets()
    }
    
    public func loadKeyPair() -> Maybe<Pair> {
        return bridge.mnemonicPromptingIfNeeded
            .map { [unowned self] mnemonic -> Pair in
                return self.deriver.derive(mnemonic: mnemonic, passphrase: nil, index: 0)
            }
    }
    
    // MARK: Private
    
    private func loadDefaultAccount() -> Maybe<WalletAccount> {
        guard let defaultAccount = defaultAccount else {
            return Maybe.empty()
        }
        return Maybe.just(defaultAccount)
    }
    
    private func createAndSaveStellarAccount() -> Maybe<WalletAccount> {
        return loadKeyPair().do(onNext: { [unowned self] stellarKeyPair in
            self.save(keyPair: stellarKeyPair)
        })
            .map { keyPair -> Account in
                // TODO: Need to localize this
                return Account(
                    index: 0,
                    publicKey: keyPair.accountID,
                    label: "My Stellar Wallet",
                    archived: false
                )
        }
    }
    
    // MARK: - Private
    
    private func save(keyPair: Pair) {
        // TODO: Need to localize this
        bridge.save(keyPair: keyPair, label: "My Stellar Wallet") { errorMessage in
            // TODO: Need to localize this
            print(errorMessage ?? "")
        }
    }
}
