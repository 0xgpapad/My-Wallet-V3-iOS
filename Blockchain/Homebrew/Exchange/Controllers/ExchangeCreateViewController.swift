//
//  ExchangeCreateViewController.swift
//  Blockchain
//
//  Created by kevinwu on 8/15/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import PlatformKit
import PlatformUIKit
import RxSwift
import SafariServices
import ToolKit

protocol ExchangeCreateDelegate: NumberKeypadViewDelegate {
    func onViewDidLoad()
    func onViewWillAppear()
    func onViewDidDisappear()
    func onDisplayRatesTapped()
    func onExchangeButtonTapped()
    func onSwapButtonTapped()
    var rightNavigationCTAType: NavigationCTAType { get }
}

/// TICKET: IOS-2501 - Fix computing max spendable balance
struct BalanceMetadata {
    let cryptoBalance: CryptoValue
    let cryptoFees: CryptoValue
    let fiatBalance: FiatValue
    let fiatFees: FiatValue
}

extension BalanceMetadata {
    func displayValue(includingFees: Bool = true) throws -> NSAttributedString? {
        let font = Font(.branded(.montserratSemiBold), size: .custom(12.0)).result
        var cryptoValue: CryptoValue = cryptoBalance
        var fiatValue: FiatValue = fiatBalance
        if includingFees {
            do {
                /// We do not want to show a negative value when showing your available balance.
                /// PAX and ETH aren't technically comparable, so this is a temporary work around.
                /// Otherwise subtracting the fees from the balance will fail since PAX fees
                /// are in ETH. 
                let adjusted = cryptoBalance.amount - cryptoFees.amount
                cryptoValue = try CryptoValue.max(CryptoValue.createFromMinorValue(adjusted, assetType: cryptoBalance.currencyType), CryptoValue.zero(assetType: cryptoValue.currencyType))
                fiatValue = try FiatValue.max(fiatBalance - fiatFees, FiatValue.zero(currencyCode: BlockchainSettings.App.shared.fiatCurrencyCode))
            } catch {
                return nil
            }
        }
        
        var description = LocalizationConstants.Swap.your + " \(cryptoValue.currencyType.displayCode) " + LocalizationConstants.Swap.balance
        if includingFees {
            description = LocalizationConstants.Swap.available + " \(cryptoValue.currencyType.displayCode)"
        }
        
        let crypto = NSAttributedString(
            string: description,
            attributes: [.font: font,
                         .foregroundColor: UIColor.brandPrimary]
        )
        let fiat = NSAttributedString(
            string: fiatValue.toDisplayString(includeSymbol: true, locale: .current),
            attributes: [.font: font,
                         .foregroundColor: UIColor.green]
        )
        let asset = NSAttributedString(
            string: cryptoValue.toDisplayString(includeSymbol: true, locale: .current),
            attributes: [.font: font,
                         .foregroundColor: UIColor.darkGray]
        )
        let formattedFiat = [fiat, asset].join(withSeparator: .space())
        let result = [crypto, formattedFiat].join(withSeparator: .lineBreak())
        return result
    }
}

// swiftlint:disable line_length
class ExchangeCreateViewController: UIViewController {
    
    private typealias AccessibilityIdentifier = AccessibilityIdentifiers.Exchange.Create
    
    // MARK: Private Static Properties
    
    static let isLargerThan5S: Bool = Constants.Booleans.IsUsingScreenSizeLargerThan5s
    static let primaryFontName: String = Constants.FontNames.montserratMedium
    static let primaryFontSize: CGFloat = isLargerThan5S ? 64.0 : Constants.FontSizes.Gigantic
    static let secondaryFontName: String = Constants.FontNames.montserratRegular
    static let secondaryFontSize: CGFloat = Constants.FontSizes.Huge

    // MARK: - IBOutlets

    @IBOutlet private var tradingPairView: TradingPairView!
    @IBOutlet private var numberKeypadView: NumberKeypadView!

    // Label to be updated when amount is being typed in
    @IBOutlet private var primaryAmountLabel: UILabel!

    // Amount being typed in converted to input crypto or input fiat
    @IBOutlet private var secondaryAmountLabel: UILabel!
    
    @IBOutlet private var walletBalanceLabel: UILabel!
    @IBOutlet private var conversionRateLabel: UILabel!
    
    fileprivate var trigger: ActionableTrigger?
    @IBOutlet private var exchangeButton: UIButton!
    @IBOutlet private var exchangeButtonBottomConstraint: NSLayoutConstraint!
    
    enum PresentationUpdate {
        case wiggleInputLabels
        case wigglePrimaryLabel
        case updatePrimaryLabel(NSAttributedString?)
        case updateSecondaryLabel(String?)
        case actionableErrorLabelTrigger(ActionableTrigger)
        case loadingIndicator(Visibility)
    }
    
    enum ViewUpdate: Update {
        case exchangeButton(Visibility)
    }
    
    enum TransitionUpdate: Transition {
        case updateBalanceMetadata(BalanceMetadata)
        case updateConversionRateLabel(NSAttributedString)
        case updateBalanceLabel(NSAttributedString)
        case primaryLabelTextColor(UIColor)
    }
    
    enum BalanceDisplayType {
        case total
        case available
    }

    // MARK: Public Properties

    weak var delegate: ExchangeCreateDelegate?

    // MARK: Private Properties

    private var analyticsRecorder: AnalyticsEventRecording {
        presenter.analyticsRecorder
    }
    private var presenter: ExchangeCreatePresenter!
    private var dependencies: ExchangeDependencies = ExchangeServices()
    private var assetAccountListPresenter: ExchangeAssetAccountListPresenter!
    private var fromAccount: AssetAccount!
    private var toAccount: AssetAccount!
    private var balanceDisplayType: BalanceDisplayType = .total
    private var balanceMetadata: BalanceMetadata?
    private let feedback: UISelectionFeedbackGenerator = UISelectionFeedbackGenerator()
    private let disposables = CompositeDisposable()
    private let bag: DisposeBag = DisposeBag()

    private let loadingViewPresenter: LoadingViewPresenting = LoadingViewPresenter.shared
    
    // MARK: Lifecycle
    
    deinit {
        disposables.dispose()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LocalizationConstants.Swap.swap
        let disposable = dependenciesSetup()
            .subscribeOn(MainScheduler.asyncInstance)
            .observeOn(MainScheduler.instance)
            .subscribe(onCompleted: { [weak self] in
                guard let self = self else { return }
                self.viewsSetup()
                self.delegate?.onViewDidLoad()
            })
        walletBalanceLabel.addGestureRecognizer(balanceTapGesture)
        disposables.insertWithDiscardableResult(disposable)
        exchangeButton.isExclusiveTouch = true
        setupNotifications()
        setupAccessibility()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        delegate?.onViewWillAppear()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        delegate?.onViewDidDisappear()
    }

    // MARK: Private

    private func setupAccessibility() {
        primaryAmountLabel.accessibilityIdentifier = AccessibilityIdentifier.primaryAmountLabel
        secondaryAmountLabel.accessibilityIdentifier = AccessibilityIdentifier.secondaryAmountLabel
        walletBalanceLabel.accessibilityIdentifier = AccessibilityIdentifier.walletBalanceLabel
        conversionRateLabel.accessibilityIdentifier = AccessibilityIdentifier.conversionRateLabel
        exchangeButton.accessibilityIdentifier = Accessibility.Identifier.General.mainCTAButton
    }
    
    private func viewsSetup() {
        [primaryAmountLabel, secondaryAmountLabel].forEach {
            $0?.textColor = UIColor.brandPrimary
        }
        
        [walletBalanceLabel, conversionRateLabel].forEach {
            let font = Font(.branded(.montserratMedium), size: .custom(12.0)).result
            $0?.attributedText = NSAttributedString(string: "\n\n", attributes: [.font: font])
        }
        
        tradingPairView.delegate = self

        exchangeButton.layer.cornerRadius = Constants.Measurements.buttonCornerRadius

        exchangeButton.setTitle(LocalizationConstants.Swap.exchange, for: .normal)
        
        let isAboveSE = DevicePresenter.type != .superCompact
        exchangeButtonBottomConstraint.constant = isAboveSE ? 16.0 : 0.0
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    private func setupNotifications() {
        NotificationCenter.when(Constants.NotificationKeys.swapFlowCompleted) { [weak self] _ in
            guard let self = self else { return }
            self.showSwapSuccessAlert()
        }
        
        NotificationCenter.when(Constants.NotificationKeys.swapToPaxFlowCompleted) { [weak self] _ in
            guard let self = self else { return }
            self.isETHAirdropEligible()
                .subscribeOn(MainScheduler.instance)
                .observeOn(MainScheduler.asyncInstance)
                .subscribe(onSuccess: { eligible in
                    switch eligible {
                    case true:
                        self.showETHAirdropAlert()
                    case false:
                        self.showSwapSuccessAlert()
                    }
                }, onError: { error in
                    Logger.shared.error(error)
                })
            .disposed(by: self.bag)
        }
    }
    
    private func isETHAirdropEligible() -> Single<Bool> {
        BlockchainDataRepository.shared.nabuUser.take(1).asSingle().flatMap { user -> Single<Bool> in
            guard let tiers = user.tiers else { return Single.just(false) }
            guard let tags = user.tags else { return Single.just(false) }
            let eligible = tiers.current == .tier2 && tags.powerPax == nil
            return Single.just(eligible)
        }
    }

    fileprivate func dependenciesSetup() -> Completable {
        Completable.create(subscribe: { [weak self] observer -> Disposable in
            guard let self = self else {
                observer(.completed)
                return Disposables.create()
            }
            let btcAccount = self.dependencies.assetAccountRepository.accounts(for: .bitcoin)
            let ethAccount = self.dependencies.assetAccountRepository.accounts(for: .ethereum)
            
            let disposable = Single.zip(btcAccount, ethAccount)
                .subscribeOn(MainScheduler.asyncInstance)
                .observeOn(MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] (bitcoin, ethereum) in
                    guard let self = self else { return }
                    guard let bitcoinAccount = bitcoin.first else { return }
                    guard let ethereumAccount = ethereum.first else { return }
                    self.fromAccount = bitcoinAccount
                    self.toAccount = ethereumAccount
                    // DEBUG - ideally add an .empty state for a blank/loading state for MarketsModel here.
                    let interactor = ExchangeCreateInteractor(
                        dependencies: self.dependencies,
                        model: MarketsModel(
                            marketPair: MarketPair(fromAccount: self.fromAccount, toAccount: self.toAccount),
                            fiatCurrencyCode: BlockchainSettings.sharedAppInstance().fiatCurrencyCode,
                            fiatCurrencySymbol: BlockchainSettings.App.shared.fiatCurrencySymbol,
                            fix: .baseInFiat,
                            volume: "0"
                        )
                    )
                    self.assetAccountListPresenter = ExchangeAssetAccountListPresenter(view: self)
                    self.numberKeypadView.delegate = self
                    self.presenter = ExchangeCreatePresenter(interactor: interactor)
                    self.presenter.interface = self
                    interactor.output = self.presenter
                    self.delegate = self.presenter
                    observer(.completed)
                })
            self.disposables.insertWithDiscardableResult(disposable)
            return Disposables.create()
        })
    }
    
    fileprivate func presentURL(_ url: URL) {
        let viewController = SFSafariViewController(url: url)
        guard let controller = AppCoordinator.shared.tabControllerManager.tabViewController else { return }
        viewController.modalPresentationStyle = .overCurrentContext
        controller.present(viewController, animated: true, completion: nil)
    }
    
    private func showETHAirdropAlert() {
        let alert = AlertModel(
            headline: LocalizationConstants.Swap.exchangeStarted,
            body: LocalizationConstants.Swap.exchangeAirdropDescription,
            actions: [exchangeHistoryAction],
            image: #imageLiteral(resourceName: "green-checkmark"),
            style: .sheet
        )
        let alertView = AlertView.make(with: alert) { action in
            guard case let .block(block)? = action.metadata else { return }
            block()
        }
        alertView.show()
    }
    
    private func showSwapSuccessAlert() {
        let alert = AlertModel(
            headline: LocalizationConstants.Swap.successfulExchangeDescription,
            body: nil,
            actions: [exchangeHistoryAction],
            image: #imageLiteral(resourceName: "green-checkmark"),
            style: .sheet
        )
        let alertView = AlertView.make(with: alert) { action in
            guard case let .block(block)? = action.metadata else { return }
            block()
        }
        alertView.show()
    }
    
    private var exchangeHistoryAction: AlertAction {
        AlertAction(
            style: .default(LocalizationConstants.Swap.viewOrderDetails),
            metadata: .block({ [weak self] in
                guard let self = self else { return }
                guard let root = UIApplication.shared.keyWindow?.rootViewController else {
                        Logger.shared.error("No navigation controller found")
                        return
                }
                self.analyticsRecorder.record(event: AnalyticsEvents.Swap.swapViewHistoryButtonClick)
                let controller = ExchangeListViewController.make(with: self.dependencies)
                let navController = BaseNavigationController(rootViewController: controller)
                navController.modalPresentationStyle = .fullScreen
                navController.modalTransitionStyle = .coverVertical
                root.present(navController, animated: true, completion: nil)
            }
            )
        )
    }
    
    // MARK: - IBActions

    @IBAction private func ratesViewTapped(_ sender: UITapGestureRecognizer) {
        delegate?.onDisplayRatesTapped()
    }
    
    @IBAction private func exchangeButtonTapped(_ sender: Any) {
        analyticsRecorder.record(event: AnalyticsEvents.Swap.swapFormConfirmClick)
        delegate?.onExchangeButtonTapped()
    }
    
    @objc func balanceTapped(_ sender: UITapGestureRecognizer) {
        balanceDisplayType = balanceDisplayType == .available ? .total : .available
        guard let metadata = balanceMetadata else { return }
        feedback.prepare()
        feedback.selectionChanged()
        walletBalanceLabel.attributedText = try? metadata.displayValue(includingFees: balanceDisplayType == .available)
    }
    
    // MARK: - Lazy Properties
    
    private lazy var balanceTapGesture: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(balanceTapped(_:)))
        return tap
    }()
}

// MARK: - Styling
extension ExchangeCreateViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .default
    }

    private func addStyleToView(_ viewToEdit: UIView) {
        viewToEdit.layer.cornerRadius = 4.0
        viewToEdit.layer.borderWidth = 1.0
        viewToEdit.layer.borderColor = UIColor.brandPrimary.cgColor
    }
}

extension ExchangeCreateViewController: NumberKeypadViewDelegate {
    func onDelimiterTapped() {
        delegate?.onDelimiterTapped()
    }
    
    func onAddInputTapped(value: String) {
        delegate?.onAddInputTapped(value: value)
    }

    func onBackspaceTapped() {
        delegate?.onBackspaceTapped()
    }
}

extension ExchangeCreateViewController: ExchangeCreateInterface {
    
    func exchangeStatusUpdated() {
        guard let navController = navigationController as? BaseNavigationController else { return }
        navController.update()
        
    }
    
    func showTiers() {
        let disposable = KYCTiersViewController.routeToTiers(
            fromViewController: self
        )
        disposables.insertWithDiscardableResult(disposable)
    }
    
    func apply(transitionPresentation: TransitionPresentationUpdate<ExchangeCreateInterface.TransitionUpdate>) {
        transitionPresentation.transitionType.perform(with: view, animations: { [weak self] in
            guard let this = self else { return }
            transitionPresentation.transitions.forEach({ this.apply(transition: $0) })
        })
    }
    
    func apply(transitionUpdateGroup: ExchangeCreateInterface.TransitionUpdateGroup) {
        let completion: () -> Void = {
            transitionUpdateGroup.finish()
        }
        transitionUpdateGroup.preparations.forEach({ apply(transition: $0) })
        transitionUpdateGroup.transitionType.perform(with: view, animations: { [weak self] in
            transitionUpdateGroup.transitions.forEach({ self?.apply(transition: $0) })
        }, completion: completion)
    }
    
    func apply(presentationUpdateGroup: ExchangeCreateInterface.PresentationUpdateGroup) {
        let completion: () -> Void = {
            presentationUpdateGroup.finish()
        }
        presentationUpdateGroup.preparations.forEach({ apply(update: $0) })
        presentationUpdateGroup.animationType.perform(animations: { [weak self] in
            presentationUpdateGroup.animations.forEach({ self?.apply(update: $0) })
        }, completion: completion)
    }
    
    func apply(presentationUpdates: [ExchangeCreateInterface.PresentationUpdate]) {
        presentationUpdates.forEach({ apply(presentationUpdate: $0) })
    }
    
    func apply(animatedUpdate: ExchangeCreateInterface.AnimatedUpdate) {
        animatedUpdate.animationType.perform(animations: { [weak self] in
            guard let this = self else { return }
            animatedUpdate.animations.forEach({ this.apply(update: $0) })
        })
    }
    
    func apply(viewUpdates: [ExchangeCreateInterface.ViewUpdate]) {
        viewUpdates.forEach({ apply(update: $0) })
    }
    
    func apply(transition: TransitionUpdate) {
        switch transition {
        case .updateBalanceMetadata(let metadata):
            balanceMetadata = metadata
            let value = try? metadata.displayValue(includingFees: balanceDisplayType == .available)
            walletBalanceLabel.attributedText = value
        case .primaryLabelTextColor(let color):
            primaryAmountLabel.textColor = color
        case .updateConversionRateLabel(let attributedString):
            conversionRateLabel.attributedText = attributedString
        case .updateBalanceLabel(let attributedString):
            walletBalanceLabel.attributedText = attributedString
        }
    }
    
    func apply(update: ViewUpdate) {
        switch update {
        case .exchangeButton(let visibility):
            exchangeButton.alpha = visibility.defaultAlpha
        }
    }
    
    func apply(presentationUpdate: PresentationUpdate) {
        switch presentationUpdate {
        case .loadingIndicator(let visibility):
            switch visibility {
            case .visible:
                loadingViewPresenter.show(with: LocalizationConstants.Swap.confirming)
            case .hidden:
                loadingViewPresenter.hide()
            }
        case .updatePrimaryLabel(let value):
            primaryAmountLabel.attributedText = value
        case .updateSecondaryLabel(let value):
            secondaryAmountLabel.text = value
        case .wiggleInputLabels:
            primaryAmountLabel.wiggle()
            secondaryAmountLabel.wiggle()
        case .wigglePrimaryLabel:
            primaryAmountLabel.wiggle()
        case .actionableErrorLabelTrigger:
            break
        }
    }

    func updateTradingPairView(pair: TradingPair, fix: Fix) {
        let fromAsset = pair.from
        let toAsset = pair.to

        let transitionUpdate = TradingPairView.TradingTransitionUpdate(
            transitions: [
                .images(left: fromAsset.whiteImageSmall, right: toAsset.whiteImageSmall),
                .titles(left: "", right: "")
            ],
            transition: .crossFade(duration: 0.2)
        )

        let presentationUpdate = TradingPairView.TradingPresentationUpdate(
            animations: [
                .backgroundColors(left: fromAsset.brandColor, right: toAsset.brandColor),
                .swapTintColor(#colorLiteral(red: 0, green: 0.2901960784, blue: 0.4862745098, alpha: 1)),
                .titleColor(#colorLiteral(red: 0, green: 0.2901960784, blue: 0.4862745098, alpha: 1))
            ],
            animation: .none
        )
        let model = TradingPairView.Model(
            transitionUpdate: transitionUpdate,
            presentationUpdate: presentationUpdate
        )
        tradingPairView.apply(model: model)
    }

    func updateTradingPairViewValues(left: String, right: String) {
        let transitionUpdate = TradingPairView.TradingTransitionUpdate(
            transitions: [.titles(left: left, right: right)],
            transition: .none
        )
        tradingPairView.apply(transitionUpdate: transitionUpdate)
    }
    
    func exchangeButtonEnabled(_ enabled: Bool) {
        exchangeButton.isEnabled = enabled
        exchangeButton.alpha = enabled ? 1.0 : 0.5
    }

    func isExchangeButtonEnabled() -> Bool {
        exchangeButton.isEnabled
    }
    
    func showSummary(orderTransaction: OrderTransaction, conversion: Conversion) {
        let model = ExchangeDetailPageModel(type: .confirm(orderTransaction, conversion))
        let confirmController = ExchangeDetailViewController.make(with: model, dependencies: ExchangeServices())
        navigationController?.pushViewController(confirmController, animated: true)
    }
}

// MARK: - TradingPairViewDelegate

extension ExchangeCreateViewController: TradingPairViewDelegate {
    func onLeftButtonTapped(_ view: TradingPairView, title: String) {
        analyticsRecorder.record(event: AnalyticsEvents.Swap.swapLeftAssetClick)
        assetAccountListPresenter.presentPicker(excludingAccount: fromAccount, for: .exchanging)
    }

    func onRightButtonTapped(_ view: TradingPairView, title: String) {
        analyticsRecorder.record(event: AnalyticsEvents.Swap.swapRightAssetClick)
        assetAccountListPresenter.presentPicker(excludingAccount: toAccount, for: .receiving)
    }

    func onSwapButtonTapped(_ view: TradingPairView) {
        analyticsRecorder.record(event: AnalyticsEvents.Swap.swapReversePairClick)
        // TICKET: https://blockchain.atlassian.net/browse/IOS-1350
    }
}

// MARK: - ExchangeAssetAccountListView

extension ExchangeCreateViewController: ExchangeAssetAccountListView {
    func showPicker(for assetAccounts: [AssetAccount], action: ExchangeAction) {
        let actionSheetController = UIAlertController(title: action.title, message: nil, preferredStyle: .actionSheet)

        // Insert actions
        assetAccounts.forEach { account in
            let alertAction = UIAlertAction(title: account.name, style: .default, handler: { [unowned self] _ in
                Logger.shared.debug("Selected account titled: '\(account.name)' of type: '\(account.address.cryptoCurrency.displayCode)'")
                
                /// Note: Users should not be able to exchange between
                /// accounts with the same assetType.
                switch action {
                case .exchanging:
                    if account.address.cryptoCurrency == self.toAccount.address.cryptoCurrency {
                        self.toAccount = self.fromAccount
                    }
                    
                    self.fromAccount = account
                case .receiving:
                    if account.address.cryptoCurrency == self.fromAccount.address.cryptoCurrency {
                        self.fromAccount = self.toAccount
                    }
                    self.toAccount = account
                }
                self.onTradingPairChanged()
            })
            actionSheetController.addAction(alertAction)
        }
        actionSheetController.addAction(
            UIAlertAction(title: LocalizationConstants.cancel, style: .cancel)
        )
        
        present(actionSheetController, animated: true)
    }

    private func onTradingPairChanged() {
        presenter.changeMarketPair(
            marketPair: MarketPair(
                fromAccount: fromAccount,
                toAccount: toAccount
            )
        )
    }
}

extension ExchangeCreateViewController: UIViewControllerTransitioningDelegate {
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        ModalAnimator(operation: .dismiss, duration: 0.4)
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        ModalAnimator(operation: .present, duration: 0.4)
    }
}

extension ExchangeCreateViewController: ActionableLabelDelegate {
    func targetRange(_ label: ActionableLabel) -> NSRange? {
        trigger?.actionRange()
    }

    func actionRequestingExecution(label: ActionableLabel) {
        guard let trigger = trigger else { return }
        trigger.execute()
    }
}

extension ExchangeCreateViewController: NavigatableView {
    var leftCTATintColor: UIColor {
        .white
    }
    
    var rightCTATintColor: UIColor {
        guard let presenter = presenter else { return .white }
        if case .error(let value) = presenter.status {
            return value == .noVolumeProvided ? .white : .pending
        }
        
        return .white
    }
    
    var leftNavControllerCTAType: NavigationCTAType {
        .menu
    }
    
    var rightNavControllerCTAType: NavigationCTAType {
        delegate?.rightNavigationCTAType ?? .help
    }

    var barStyle: Screen.Style.Bar {
        .lightContent()
    }
    
    func navControllerRightBarButtonTapped(_ navController: UINavigationController) {
        if case let .error(value) = presenter.status, value != .noVolumeProvided {
            analyticsRecorder.record(
                event: AnalyticsEvents.Swap.swapFormConfirmErrorClick(error: value)
            )
            
            let action = AlertAction(style: .default(LocalizationConstants.Swap.done))
            var actions = [action]
            if let url = value.url {
                let learnMore = AlertAction(
                    style: .confirm(LocalizationConstants.Swap.learnMore),
                    metadata: .url(url)
                )
                actions.append(learnMore)
            }
            let model = AlertModel(
                headline: value.title,
                body: value.description,
                actions: actions,
                image: value.image,
                style: .sheet
            )
            let alert = AlertView.make(with: model) { [weak self] action in
                guard let self = self else { return }
                guard let data = action.metadata else { return }
                guard case let .url(url) = data else { return }
                self.presentURL(url)
            }
            alert.show()
            return
        }
        
        guard let endpoint = URL(string: "https://blockchain.zendesk.com/") else { return }
        guard let url = URL.endpoint(
            endpoint,
            pathComponents: ["hc", "en-us", "requests", "new"],
            queryParameters: ["ticket_form_id" : "360000180551"]
            ) else { return }
        
        let orderHistory = BottomSheetAction(title: LocalizationConstants.Swap.orderHistory, metadata: .block({
            guard let root = UIApplication.shared.keyWindow?.rootViewController else {
                Logger.shared.error("No navigation controller found")
                return
            }
            let controller = ExchangeListViewController.make(with: self.dependencies)
            let navController = BaseNavigationController(rootViewController: controller)
            navController.modalTransitionStyle = .coverVertical
            navController.modalPresentationStyle = .fullScreen
            root.present(navController, animated: true, completion: nil)
        }))
        let viewLimits = BottomSheetAction(title: LocalizationConstants.Swap.viewMySwapLimit, metadata: .block({
            _ = KYCTiersViewController.routeToTiers(fromViewController: self)
        }))
        let contactSupport = BottomSheetAction(title: LocalizationConstants.KYC.contactSupport, metadata: .url(url))
        let model = BottomSheet(
            title: LocalizationConstants.Swap.swapInfo,
            dismissalTitle: LocalizationConstants.Swap.close,
            actions: [orderHistory, contactSupport, viewLimits]
        )
        let sheet = BottomSheetView.make(with: model) { [weak self] action in
            guard let this = self else { return }
            guard let value = action.metadata else { return }
            
            switch value {
            case .url(let url):
                this.presentURL(url)
            case .block(let block):
                block()
            case .pop:
                this.navigationController?.popViewController(animated: true)
            case .dismiss:
                this.dismiss(animated: true, completion: nil)
            case .payload:
                break
            }
        }
        sheet.show()
    }
    
    func navControllerLeftBarButtonTapped(_ navController: UINavigationController) {
        AppCoordinator.shared.toggleSideMenu()
    }
}
