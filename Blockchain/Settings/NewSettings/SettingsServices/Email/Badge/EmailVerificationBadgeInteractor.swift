//
//  EmailVerificationBadgeInteractor.swift
//  Blockchain
//
//  Created by AlexM on 12/18/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import RxRelay
import PlatformKit

final class EmailVerificationBadgeInteractor: BadgeAssetInteracting {
    
    // MARK: - Types
    
    typealias InteractionState = BadgeAsset.State.BadgeItem.Interaction
    
    var state: Observable<InteractionState> {
        return stateRelay.asObservable()
    }
        
    // MARK: - Private Accessors
    
    private let stateRelay = BehaviorRelay<InteractionState>(value: .loading)
    private let disposeBag = DisposeBag()
    
    // MARK: - Setup
    
    init(service: SettingsServiceAPI) {
        service
            .valueObservable
                .map { $0.isEmailVerified }
                .map { $0 ? .verified : .unverified }
                .map { .loaded(next: $0) }
                // TODO: Error handing
                .catchErrorJustReturn(.loading)
                .startWith(.loading)
                .bind(to: stateRelay)
                .disposed(by: disposeBag)
    }
}
