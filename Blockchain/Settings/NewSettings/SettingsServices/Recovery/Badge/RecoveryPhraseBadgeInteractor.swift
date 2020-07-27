//
//  RecoveryPhraseBadgeInteractor.swift
//  Blockchain
//
//  Created by AlexM on 12/18/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import PlatformUIKit
import RxRelay
import RxSwift

final class RecoveryPhraseBadgeInteractor: DefaultBadgeAssetInteractor {

    init(provider: RecoveryPhraseStatusProviding) {
        super.init()
        provider.isRecoveryPhraseVerifiedObservable
            .map { $0 == true ? .confirmed : .unconfirmed }
            .map { .loaded(next: $0) }
            .bindAndCatch(to: stateRelay)
            .disposed(by: disposeBag)
    }
}

