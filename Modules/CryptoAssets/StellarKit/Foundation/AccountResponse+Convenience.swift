// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import PlatformKit
import stellarsdk

// MARK: StellarSDK Convenience

extension AccountResponse {
    var totalBalance: CryptoValue {
        let value = balances.reduce(Decimal(0)) { $0 + (Decimal(string: $1.balance) ?? 0) }
        return CryptoValue.create(major: value, currency: .stellar)
    }

    func toAssetAccountDetails(minimumBalance: CryptoValue) -> StellarAccountDetails {
        let account = StellarAssetAccount(
            accountAddress: accountId,
            name: CryptoCurrency.stellar.defaultWalletName,
            description: CryptoCurrency.stellar.defaultWalletName,
            sequence: Int(sequenceNumber),
            subentryCount: subentryCount
        )
        var actionableBalance: CryptoValue = .stellarZero
        if let balanceMinusReserve = try? totalBalance - minimumBalance, balanceMinusReserve.isPositive {
            actionableBalance = balanceMinusReserve
        }
        return StellarAccountDetails(
            account: account,
            balance: totalBalance,
            actionableBalance: actionableBalance
        )
    }
}
