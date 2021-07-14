// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import DIKit
import Localization
import PlatformKit
import PlatformUIKit
import RxCocoa
import RxSwift
import ToolKit

protocol AccountAuxiliaryViewInteractorAPI {
    /// The view has been tapped.
    /// This should trigger an event that presents
    /// a new screen to select a different account.
    var auxiliaryViewTappedRelay: PublishRelay<Void> { get }
}

extension AccountAuxiliaryViewInteractorAPI {
    /// Streams auxiliary view tap events.
    var auxiliaryViewTapped: Observable<Void> {
        auxiliaryViewTappedRelay
            .asObservable()
    }
}

final class AccountAuxiliaryViewInteractor: AccountAuxiliaryViewInteractorAPI {

    // MARK: - Types

    private typealias LocalizationIds = LocalizationConstants.Transaction

    // MARK: - State

    struct State {
        let title: String
        let subtitle: String
        let imageResource: ImageResource
    }

    // MARK: - AccountAuxiliaryViewInteractorAPI

    let auxiliaryViewTappedRelay = PublishRelay<Void>()

    // MARK: Public Properties

    var state: Observable<State> {
        stateRelay
            .asObservable()
            .share(replay: 1, scope: .whileConnected)
    }

    let stateRelay = PublishRelay<State>()

    // MARK: - Connect API

    func connect(stream: Observable<BlockchainAccount>) -> Disposable {
        stream
            .map { account -> State in
                switch account {
                case let bank as LinkedBankAccount:
                    let type = bank.accountType.title
                    let description = type + " \(LocalizationIds.account)"
                    let subtitle = description + " \(bank.accountNumber)"
                    return .init(
                        title: bank.label,
                        subtitle: subtitle,
                        imageResource: bank.logoResource
                    )
                default:
                    unimplemented()
                }
            }
            .bindAndCatch(to: stateRelay)
    }
}