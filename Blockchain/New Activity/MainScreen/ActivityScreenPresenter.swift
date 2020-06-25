//
//  ActivityScreenPresenter.swift
//  Blockchain
//
//  Created by Daniel Huri on 16/03/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformUIKit
import RxCocoa
import RxDataSources
import RxRelay
import RxSwift

final class ActivityScreenPresenter {
    
    // MARK: - Types
    
    private typealias AccessibilityId = Accessibility.Identifier.Activity
    private typealias LocalizedString = LocalizationConstants.Activity.MainScreen
    
    // MARK: - Public Properties
    
    /// The screen title
    let title = LocalizedString.title
    
    /// The `SelectionButtonView`
    let selectionButtonViewModel: SelectionButtonViewModel
    
    /// The title of the empty state
    var emptyActivityTitle: LabelContent {
        .init(text: LocalizedString.Empty.title,
              font: .main(.semibold, 20.0),
              color: .titleText,
              alignment: .center,
              accessibility: .none)
    }
    
    /// The subtitle of the empty state
    var emptyActivitySubtitle: LabelContent {
        .init(text: LocalizedString.Empty.subtitle,
              font: .main(.medium, 14.0),
              color: .descriptionText,
              alignment: .center,
              accessibility: .none)
    }
    
    /// The visibility state of the subviews that should be
    /// visible when there are no activity events for the
    /// selected wallet
    var emptySubviewsVisibility: Driver<Visibility> {
        interactor
            .isEmpty
            .map { $0 ? .visible : .hidden }
            .asDriver(onErrorJustReturn: .hidden)
    }
    
    /// All the sections that should be displayed in the
    /// Activity screen
    var sectionsObservable: Observable<[ActivityItemsSectionViewModel]> {
        activityItemsObservable
    }
    
    // MARK: - Private Properties (Rx)
    
    /// Observable of the `ActivityItemsSectionViewModel` section
    private var activityItemsObservable: Observable<[ActivityItemsSectionViewModel]> {
        Observable.combineLatest(activityCellItems, skeletonCellItems)
            .map { $0.0 + $0.1 }
            .map { ActivityItemsSectionViewModel(items: $0) }
            .map { [$0] }
    }
    
    /// The `[ActivityCellItem]` for only `.activity` types
    private var activityCellItems: Observable<[ActivityCellItem]> {
        interactor
            .state
            .map { $0.value ?? [] }
            .map(weak: self) { (self, events) -> [ActivityItemPresenter] in
                events.map { ActivityItemPresenter(interactor: $0) }
            }
            .map { presenters in presenters.map { .activity($0) } }
    }
    
    /// The `[ActivityCellItem]` for only `.skeleton` types.
    /// Used for the loading state.
    private var skeletonCellItems: Observable<[ActivityCellItem]> {
        interactor
            .state
            .map { $0.isCalculating ? Array(1...20) : [] }
            .map { items in items.map { .skeleton($0) } }
    }

    let selectedModelRelay: PublishRelay<ActivityCellItem> = .init()
    
    // MARK: - Injected
    
    private let qrScannerRouter: QRScannerRouting
    private let drawerRouter: DrawerRouting
    private let router: ActivityRouterAPI
    private let interactor: ActivityScreenInteractor
    
    // MARK: - Private Properties
    
    private let disposeBag = DisposeBag()
    
    // MARK: - Setup
    
    init(router: ActivityRouterAPI,
         interactor: ActivityScreenInteractor,
         qrScannerRouter: QRScannerRouting = AppCoordinator.shared,
         drawerRouter: DrawerRouting = AppCoordinator.shared) {
        self.qrScannerRouter = qrScannerRouter
        self.drawerRouter = drawerRouter
        self.router = router
        self.interactor = interactor
        
        selectionButtonViewModel = SelectionButtonViewModel()
        selectionButtonViewModel.shouldShowSeparatorRelay.accept(true)
        
        selectionButtonViewModel.tap
            .emit(onNext: { [unowned router] in
                router.showWalletSelectionScreen()
            })
            .disposed(by: disposeBag)
        
        interactor
            .selectedData
            .map { SelectionButtonViewModel.LeadingContent.content(from: $0) }
            .bind(to: selectionButtonViewModel.leadingContentTypeRelay)
            .disposed(by: disposeBag)
        
        let titleObservable: Observable<String> = interactor
            .selectedData
            .map { selection in
                switch selection {
                case .all:
                    return LocalizedString.Item.allWallets
                case .custodial(let currency):
                    return currency.displayCode + " " + LocalizedString.Item.tradeWallet
                case .nonCustodial(let currency):
                    return currency.displayCode + " " + LocalizedString.Item.wallet
                }
            }
        
        titleObservable
            .bind(to: selectionButtonViewModel.titleRelay)
            .disposed(by: disposeBag)
        
        titleObservable
            .map { value in .id("\(AccessibilityId.WalletSelectorView.titleLabel).\(value)") }
            .bind(to: selectionButtonViewModel.titleAccessibilityRelay)
            .disposed(by: disposeBag)
        
        interactor
            .selectedData
            .map { selection in
                switch selection {
                case .all:
                    return .init(
                        imageName: "icon-disclosure-down-small",
                        renderingMode: .template(.descriptionText)
                    )
                case .custodial,
                     .nonCustodial:
                    return .init(
                        imageName: "icon-disclosure-down-small",
                        accessibility: .none,
                        renderingMode: .template(.descriptionText)
                    )
                }
            }
            .bind(to: selectionButtonViewModel.trailingImageViewContentRelay)
            .disposed(by: disposeBag)
        
        let subtitleObservable: Observable<String> = Observable.combineLatest(
            interactor.activityBalance,
            interactor.fiatCurrency
        )
        .map { values in
            let amount = values.0
            let code = values.1.code
            return amount.toDisplayString(includeSymbol: true) + " \(code)"
        }
        
        subtitleObservable
            .bind(to: selectionButtonViewModel.subtitleRelay)
            .disposed(by: disposeBag)
        
        subtitleObservable
            .map { value in .id("\(AccessibilityId.WalletSelectorView.subtitleLabel).\(value)") }
            .bind(to: selectionButtonViewModel.subtitleAccessibilityRelay)
            .disposed(by: disposeBag)

        selectedModelRelay
            .bind { [weak self] model in
                guard case let .activity(presenter) = model else { return }
                self?.router.showTransactionScreen(with: presenter.viewModel.event)
            }
            .disposed(by: disposeBag)
    }
    
    func refresh() {
        interactor.refresh()
    }
    
    // MARK: - Navigation
    
    /// Should be invoked upon tapping navigation bar leading button
    func navigationBarLeadingButtonPressed() {
        drawerRouter.toggleSideMenu()
    }
    
    /// Should be invoked upon tapping navigation bar trailing button
    func navigationBarTrailingButtonPressed() {
        qrScannerRouter.routeToQrScanner()
    }
}

fileprivate extension SelectionButtonViewModel.LeadingContent {
    static func content(from selection: WalletPickerSelection) -> SelectionButtonViewModel.LeadingContentType {
        switch selection {
        case .all:
            return .image(
                .init(name: "icon-card",
                      background: .lightBadgeBackground,
                      cornerRadius: .round,
                      size: .init(
                        width: 32,
                        height: 32
                    )
                )
            )
        case .custodial(let currency),
             .nonCustodial(let currency):
            return .image(
                .init(name: currency.filledImageLargeName,
                      background: .clear,
                      offset: 0,
                      cornerRadius: .round,
                      size: .init(
                        width: 32,
                        height: 32
                    )
                )
            )
        }
    }
}