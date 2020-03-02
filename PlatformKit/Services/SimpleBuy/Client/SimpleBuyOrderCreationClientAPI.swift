//
//  SimpleBuyOrderCreationClientAPI.swift
//  PlatformKit
//
//  Created by Daniel Huri on 05/02/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift

public protocol SimpleBuyOrderCreationClientAPI: class {
    
    /// Creates a buy order using the given data
    func create(order: SimpleBuyOrderCreationData.Request,
                token: String) -> Single<SimpleBuyOrderCreationData.Response>
}

