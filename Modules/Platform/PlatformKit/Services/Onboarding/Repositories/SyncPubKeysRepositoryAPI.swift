// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import RxSwift

public protocol SyncPubKeysRepositoryAPI: class {
    func set(syncPubKeys: Bool) -> Completable
}
