// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import PlatformKit
import RxRelay
import RxSwift

final class EmptySwapActivityItemEventService: SwapActivityItemEventServiceAPI {
    var swapActivityEvents: Single<[SwapActivityItemEvent]> { .just([]) }

    var swapActivityObservable: Observable<[SwapActivityItemEvent]> { .just([]) }

    var custodial: Observable<ActivityItemEventsLoadingState> { .just(.loaded(next: [])) }

    var nonCustodial: Observable<ActivityItemEventsLoadingState> { .just(.loaded(next: [])) }

    var state: Observable<ActivityItemEventsLoadingState> { .just(.loaded(next: [])) }

    let fetchTriggerRelay: PublishRelay<Void> = .init()
}
