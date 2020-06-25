//
//  SwipeReceiveSwitchViewInteractor.swift
//  Blockchain
//
//  Created by AlexM on 1/13/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import PlatformUIKit
import RxCocoa
import RxRelay
import RxSwift

class SwipeReceiveSwitchViewInteractor: SwitchViewInteracting {
    
    typealias InteractionState = LoadingState<SwitchInteractionAsset>
    
    var state: Observable<InteractionState> {
        stateRelay.asObservable()
    }
    
    var switchTriggerRelay = PublishRelay<Bool>()
    
    private let stateRelay = BehaviorRelay<InteractionState>(value: .loading)
    private let disposeBag = DisposeBag()

    init(appSettings: BlockchainSettings.App) {
        
        Observable.just(appSettings.swipeToReceiveEnabled)
            .map { .loaded(next: .init(isOn: $0, isEnabled: true)) }
            .bind(to: stateRelay)
            .disposed(by: disposeBag)
        
        switchTriggerRelay.do(onNext: { value in
            appSettings.swipeToReceiveEnabled = value
        })
        .map { .loaded(next: .init(isOn: $0, isEnabled: true)) }
        .bind(to: stateRelay)
        .disposed(by: disposeBag)
    }
}

