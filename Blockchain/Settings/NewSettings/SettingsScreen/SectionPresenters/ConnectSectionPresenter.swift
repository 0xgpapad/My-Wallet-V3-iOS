//
//  ConnectSectionPresenter.swift
//  Blockchain
//
//  Created by Alex McGregor on 7/14/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import RxSwift

final class ConnectSectionPresenter: SettingsSectionPresenting {
    
    typealias State = SettingsSectionLoadingState
    
    let sectionType: SettingsSectionType = .connect
    
    var state: Observable<State> {
        let presenter: PITConnectionCellPresenter = .init(
            pitConnectionProvider: exchangeConnectionStatusProvider
        )
        let state = State.loaded(next:
            .some(
                .init(
                    sectionType: sectionType,
                    items: [.init(cellType: .badge(.pitConnection, presenter))]
                )
            )
        )
        
        return .just(state)
    }

    private let exchangeConnectionStatusProvider: PITConnectionStatusProviding

    init(exchangeConnectionStatusProvider: PITConnectionStatusProviding) {
        self.exchangeConnectionStatusProvider = exchangeConnectionStatusProvider
    }
}
