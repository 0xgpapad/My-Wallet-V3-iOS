// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import DIKit
import FeatureTransactionDomain
import PlatformKit

extension DependencyContainer {

    // MARK: - ERC20Kit Module

    public static var erc20Kit = module {

        // MARK: Asset Agnostic

        factory { ERC20AssetFactory() as ERC20AssetFactoryAPI }

        single { ERC20HistoricalTransactionService() as ERC20HistoricalTransactionServiceAPI }

        factory { ERC20BalanceService() as ERC20BalanceServiceAPI }

        factory { ERC20AccountAPIClient() as ERC20AccountAPIClientAPI }

        factory { ERC20CryptoAssetService() as ERC20CryptoAssetServiceAPI }
    }
}
