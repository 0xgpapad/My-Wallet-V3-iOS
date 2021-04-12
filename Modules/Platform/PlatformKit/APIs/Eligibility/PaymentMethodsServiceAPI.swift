//
//  PaymentMethodsServiceAPI.swift
//  PlatformKit
//
//  Created by Dimitrios Chatzieleftheriou on 22/01/2021.
//  Copyright © 2021 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift

/// Fetches the available payment methods
public protocol PaymentMethodsServiceAPI: class {
    var paymentMethods: Observable<[PaymentMethod]> { get }
    var paymentMethodsSingle: Single<[PaymentMethod]> { get }
    var supportedCardTypes: Single<Set<CardType>> { get }
    func fetch() -> Observable<[PaymentMethod]>
    func refresh() -> Completable
}
