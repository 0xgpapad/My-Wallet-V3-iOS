// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import PlatformKit
import RxRelay
import RxSwift

final class FiatEventService: FiatItemEventServiceAPI {

    var activityEvents: Single<[ActivityItemEvent]> {
        fiat
            .fiatActivityEvents
            .map { items in items.map { .fiat($0) } }
            .catchErrorJustReturn([])
    }

    var activityObservable: Observable<[ActivityItemEvent]> {
        activityEvents
            .asObservable()
    }

    var activityLoadingStateObservable: Observable<ActivityItemEventsLoadingState> {
        _ = setup
        return activityLoadingStateRelay.asObservable()
    }

    let fiat: FiatActivityItemEventServiceAPI

    // MARK: - Private Properties

    private let activityLoadingStateRelay = BehaviorRelay<ActivityItemEventsLoadingState>(value: .loading)
    private let disposeBag = DisposeBag()

    private lazy var setup: Void = {
        fiat.state
            .catchErrorJustReturn(.loaded(next: []))
            .bindAndCatch(to: activityLoadingStateRelay)
            .disposed(by: disposeBag)
    }()

    // MARK: - Setup

    init(fiat: FiatActivityItemEventServiceAPI) {
        self.fiat = fiat
    }

    func refresh() {
        fiat.fetchTriggerRelay.accept(())
    }
}
