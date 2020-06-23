//
//  CachedValue+Setup.swift
//  PlatformKit
//
//  Created by Daniel Huri on 04/03/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import ToolKit

extension CachedValueConfiguration {
    public static func onSubscriptionAndLogin(scheduler: SchedulerType = CachedValueConfiguration.generateScheduler()) -> CachedValueConfiguration {
        .init(
            refreshType: .onSubscription,
            scheduler: scheduler,
            flushNotificationName: .logout,
            fetchNotificationName: .login
        )
    }
    
    public static func periodicAndLogin(_ time: TimeInterval, scheduler: SchedulerType = CachedValueConfiguration.generateScheduler()) -> CachedValueConfiguration {
        .init(
            refreshType: .periodic(seconds: time),
            scheduler: scheduler,
            flushNotificationName: .logout,
            fetchNotificationName: .login
        )
    }
}
