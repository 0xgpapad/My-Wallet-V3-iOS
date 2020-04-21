//
//  SimpleBuyEligibilityServiceAPI.swift
//  PlatformKit
//
//  Created by Daniel Huri on 14/02/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift

public protocol SimpleBuyEligibilityServiceAPI: class {

    /// Feature is enabled and SimpleBuyEligibilityClientAPI returns eligible for current fiat currency.
    var isEligible: Observable<Bool> { get }
    func fetch() -> Observable<Bool>
}
