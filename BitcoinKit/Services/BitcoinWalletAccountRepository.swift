//
//  BitcoinWalletAccountRepository.swift
//  BitcoinKit
//
//  Created by kevinwu on 2/5/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import RxSwift

public final class BitcoinWalletAccountRepository: WalletAccountRepositoryAPI {
    
    public typealias Account = BitcoinWalletAccount

    public typealias Bridge = BitcoinWalletBridgeAPI

    // MARK: - Properties

    /**
     The default HD Account is automatically selected when first viewing the features below in Discussion:

     Send - selected as the "From"

     Request - selected as the "To"

     Transfer All - selected as the "To".

     */
    public var defaultAccount: Single<BitcoinWalletAccount> {
        bridge.defaultWallet
    }
    
    public var accounts: Single<[BitcoinWalletAccount]> {
        bridge.wallets
    }
    
    public var activeAccounts: Single<[BitcoinWalletAccount]> {
        accounts.map { accounts in
            accounts.filter(\.isActive)
        }
    }

    private let bridge: Bridge

    // MARK: - Init
    
    public init(with bridge: Bridge) {
        self.bridge = bridge
    }
}

extension BitcoinWalletAccount {
    var isActive: Bool {
        !archived
    }
}
