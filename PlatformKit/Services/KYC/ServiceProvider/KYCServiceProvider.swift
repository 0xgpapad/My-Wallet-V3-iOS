//
//  KYCServiceProvider.swift
//  PlatformKit
//
//  Created by Daniel Huri on 10/02/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit

public final class KYCServiceProvider: KYCServiceProviderAPI {

    // MARK: - Properties

    public let tiers: KYCTiersServiceAPI
    public let user: NabuUserServiceAPI
    
    /// Computes the polling service
    public var tiersPollingService: KYCTierUpdatePollingService {
        KYCTierUpdatePollingService(tiersService: tiers)
    }
    
    // MARK: - Setup

    init(user: NabuUserServiceAPI = resolve(), tiers: KYCTiersServiceAPI = resolve()) {
        self.user = user
        self.tiers = tiers
    }
}

