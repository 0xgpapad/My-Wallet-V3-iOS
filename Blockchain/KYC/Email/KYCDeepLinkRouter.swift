//
//  KYCVerifyEmailRouter.swift
//  Blockchain
//
//  Created by kevinwu on 2/18/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit

/// Router for handling the KYC verify email flow
class KYCDeepLinkRouter: DeepLinkRouting {

    private let appSettings: BlockchainSettings.App
    private let kycSettings: KYCSettingsAPI
    private let kycCoordinator: KYCCoordinator

    init(
        appSettings: BlockchainSettings.App = resolve(),
        kycSettings: KYCSettingsAPI = KYCSettings.shared,
        kycCoordinator: KYCCoordinator = KYCCoordinator.shared
    ) {
        self.appSettings = appSettings
        self.kycSettings = kycSettings
        self.kycCoordinator = kycCoordinator
    }

    func routeIfNeeded() -> Bool {
        // Only route if the user actually tapped on the verify email link
        guard appSettings.didTapOnKycDeepLink else {
            return false
        }
        appSettings.didTapOnKycDeepLink = false

        // Only route if the user was completing kyc
        guard kycSettings.isCompletingKyc else {
            return false
        }

        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            return false
        }
        kycCoordinator.start(from: viewController)
        return true
    }
}
