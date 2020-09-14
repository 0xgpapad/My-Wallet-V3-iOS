//
//  ActivityItemEventServiceAPI.swift
//  PlatformKit
//
//  Created by Alex McGregor on 6/5/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxRelay
import RxSwift

public protocol ActivityItemEventServiceAPI {
    var activityEvents: Single<[ActivityItemEvent]> { get }
    var activityLoadingStateObservable: Observable<ActivityItemEventsLoadingState> { get }
    
    func refresh()
}

public protocol CryptoItemEventServiceAPI: ActivityItemEventServiceAPI {
    var transactional: TransactionalActivityItemEventServiceAPI { get }
    var buySell: BuySellActivityItemEventServiceAPI { get }
    var swap: SwapActivityItemEventServiceAPI { get }
}

public protocol FiatItemEventServiceAPI: ActivityItemEventServiceAPI {
    var fiat: FiatActivityItemEventServiceAPI { get }
}
