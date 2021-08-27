// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import DIKit
import PlatformKit
import RxSwift

/// Supports notices
final class DashboardNoticeInteractor {

    /// A `Single` that streams a boolean value indicating ifthe user has a lockbox linked
    var lockbox: Single<Bool> {
        Single
            .just(lockboxRepository.hasLockbox)
            // Subscribe on the main queue because of the JS layer
            .subscribeOn(MainScheduler.instance)
    }

    // MARK: - Services

    private let lockboxRepository: LockboxRepositoryAPI

    // MARK: - Setup

    init(lockboxRepository: LockboxRepositoryAPI = resolve()) {
        self.lockboxRepository = lockboxRepository
    }
}
