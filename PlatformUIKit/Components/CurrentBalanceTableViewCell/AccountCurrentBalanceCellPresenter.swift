//
//  AccountCurrentBalanceCellPresenter.swift
//  PlatformUIKit
//
//  Created by Paulo on 17/08/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import Localization
import PlatformKit
import RxCocoa
import RxSwift
import ToolKit

final class AccountCurrentBalanceCellPresenter: CurrentBalanceCellPresenting {

    private typealias AccessibilityId = Accessibility.Identifier.AccountPicker.AccountCell
    private typealias LocalizedString = LocalizationConstants.DashboardDetails.BalanceCell

    var iconImageViewContent: Driver<ImageViewContent> {
        iconImageViewContentRelay.asDriver()
    }

    var badgeImageViewModel: Driver<BadgeImageViewModel> {
        badgeRelay.asDriver()
    }

    /// Returns the description of the balance
    var title: Driver<String> {
        titleRelay.asDriver()
    }

    /// Returns the description of the balance
    var description: Driver<String> {
        descriptionRelay.asDriver()
    }
    
    var pending: Driver<String> {
       .empty()
    }
    
    var pendingLabelVisibility: Driver<Visibility> {
        .just(.hidden)
    }

    var separatorVisibility: Driver<Visibility> {
        separatorVisibilityRelay.asDriver()
    }

    let multiBadgeViewModel = MultiBadgeViewModel(
        layoutMargins: UIEdgeInsets(
            top: 8,
            left: 72,
            bottom: 16,
            right: 24
        ),
        height: 24
    )
    
    let titleAccessibilitySuffix: String
    let descriptionAccessibilitySuffix: String
    let pendingAccessibilitySuffix: String

    let assetBalanceViewPresenter: AssetBalanceViewPresenter

    // MARK: - Private Properties

    private let badgeRelay = BehaviorRelay<BadgeImageViewModel>(value: .empty)
    private let separatorVisibilityRelay: BehaviorRelay<Visibility>
    private let iconImageViewContentRelay = BehaviorRelay<ImageViewContent>(value: .empty)
    private let titleRelay = BehaviorRelay<String>(value: "")
    private let descriptionRelay = BehaviorRelay<String>(value: "")
    private let disposeBag = DisposeBag()
    private let badgeFactory = SingleAccountBadgeFactory()
    private let account: SingleAccount

    init(account: SingleAccount,
         assetAction: AssetAction,
         interactor: AssetBalanceViewInteracting,
         separatorVisibility: Visibility = .hidden) {
        self.account = account
        self.separatorVisibilityRelay = BehaviorRelay<Visibility>(value: separatorVisibility)
        titleAccessibilitySuffix = "\(AccessibilityId.titleLabel)"
        descriptionAccessibilitySuffix = "\(AccessibilityId.descriptionLabel)"
        pendingAccessibilitySuffix = "\(AccessibilityId.pendingLabel)"
        assetBalanceViewPresenter = AssetBalanceViewPresenter(
            alignment: .trailing,
            interactor: interactor,
            descriptors: .default(
                cryptoAccessiblitySuffix: "\(AccessibilityId.cryptoAmountLabel)",
                fiatAccessiblitySuffix: "\(AccessibilityId.fiatAmountLabel)"
            )
        )

        badgeFactory
            .badge(account: account, action: assetAction)
            .subscribe { [weak self] models in
                self?.multiBadgeViewModel.badgesRelay.accept(models)
            }
            .disposed(by: disposeBag)

        switch account.currencyType {
        case .fiat(let fiatCurrency):
            let badgeImageViewModel: BadgeImageViewModel = .primary(
                with: fiatCurrency.logoImageName,
                contentColor: .white,
                backgroundColor: .fiat,
                accessibilityIdSuffix: "\(AccessibilityId.badgeImageView)"
            )
            badgeImageViewModel.marginOffsetRelay.accept(0)
            badgeRelay.accept(badgeImageViewModel)
        case .crypto(let cryptoCurrency):
            let badgeImageViewModel: BadgeImageViewModel = .default(
                with: cryptoCurrency.logoImageName,
                cornerRadius: .round,
                accessibilityIdSuffix: "\(AccessibilityId.badgeImageView)"
            )
            badgeImageViewModel.marginOffsetRelay.accept(0)
            badgeRelay.accept(badgeImageViewModel)
        }
        titleRelay.accept(account.label)

        switch account.accountType {
        case .custodial:
            iconImageViewContentRelay.accept(ImageViewContent(imageName: "icon_custody_lock", bundle: Bundle.platformUIKit))
        case .nonCustodial:
            iconImageViewContentRelay.accept(.empty)
        }

        titleRelay.accept(account.label)
        descriptionRelay.accept(account.currencyType.name)
    }
}
