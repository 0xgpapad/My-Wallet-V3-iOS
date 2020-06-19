//
//  SimpleBuyServiceProvider+Conveniences.swift
//  Blockchain
//
//  Created by Daniel Huri on 04/06/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import ToolKit
import PlatformKit
import BuySellKit

extension ServiceProvider {
    
    static let `default`: ServiceProviderAPI = ServiceProvider()
    
    convenience init() {
        self.init(
            cardServiceProvider: CardServiceProvider.default,
            recordingProvider: RecordingProvider.default,
            wallet: WalletManager.shared.reactiveWallet,
            authenticationService: NabuAuthenticationService.shared,
            cacheSuite: UserDefaults.standard,
            settings: UserInformationServiceProvider.default.settings,
            dataRepository: BlockchainDataRepository.shared,
            tiersService: KYCServiceProvider.default.tiers,
            featureFetcher: AppFeatureConfigurator.shared
        )
    }
}
