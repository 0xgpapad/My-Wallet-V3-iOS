//
//  EligibilityServiceAPI.swift
//  PlatformKit
//
//  Created by Paulo on 28/10/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift

/// Brokerage (Simple Buy/Sell/Swap) Eligibility Service
public protocol EligibilityServiceAPI: AnyObject {

    /// Feature is enabled and EligibilityClientAPI returns eligible for current fiat currency.
    var isEligible: Single<Bool> { get }
    func fetch() -> Single<Bool>
}
