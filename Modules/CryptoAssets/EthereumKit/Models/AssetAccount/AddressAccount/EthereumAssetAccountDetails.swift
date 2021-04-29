// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import PlatformKit

public struct EthereumAssetAccountDetails: AssetAccountDetails, Equatable {
    public typealias Account = EthereumAssetAccount
    
    public var account: Account
    public var balance: CryptoValue
    public var nonce: UInt64
    
    public init(account: Account, balance: CryptoValue, nonce: UInt64) {
        self.account = account
        self.balance = balance
        self.nonce = nonce
    }
}
