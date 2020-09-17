//
//  AppCoordinator.swift
//  Blockchain
//
//  Created by Chris Arriola on 4/17/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import BuySellUIKit
import DIKit
import InterestKit
import InterestUIKit
import PlatformKit
import PlatformUIKit
import RxSwift

/// TODO: This class should be refactored so any view would load
/// as late as possible and also would be deallocated when is no longer in use
/// TICKET: https://blockchain.atlassian.net/browse/IOS-2619
@objc class AppCoordinator: NSObject, Coordinator, MainFlowProviding {
    
    // MARK: - Properties

    @Inject @objc static var shared: AppCoordinator

    // MARK: - Services
    
    /// Onboarding router
    @Inject var onboardingRouter: OnboardingRouter
    
    weak var window: UIWindow!

    @Inject private var authenticationCoordinator: AuthenticationCoordinator
    @Inject private var blockchainSettings: BlockchainSettings.App
    @Inject private var walletManager: WalletManager
    @Inject private var paymentPresenter: PaymentPresenter
    @Inject private var loadingViewPresenter: LoadingViewPresenting
    @LazyInject private var appFeatureConfigurator: AppFeatureConfigurator
    @LazyInject private var credentialsStore: CredentialsStoreAPI

    @Inject var airdropRouter: AirdropRouterAPI
    private var settingsRouterAPI: SettingsRouterAPI?
    private var buyRouter: BuySellUIKit.RouterAPI!
    private var sellRouter: BuySellUIKit.SellRouter!
    private var backupRouter: BackupRouterAPI?
    
    // MARK: - UIViewController Properties
    
    @objc var slidingViewController: ECSlidingViewController!
    @objc var tabControllerManager = TabControllerManager.makeFromStoryboard()
    private(set) var sideMenuViewController: SideMenuViewController!
    private let disposeBag = DisposeBag()
    
    private lazy var accountsAndAddressesNavigationController: AccountsAndAddressesNavigationController = { [unowned self] in
        let storyboard = UIStoryboard(name: "AccountsAndAddresses", bundle: nil)
        let viewController = storyboard.instantiateViewController(
            withIdentifier: "AccountsAndAddressesNavigationController"
        ) as! AccountsAndAddressesNavigationController
        viewController.modalPresentationStyle = .fullScreen
        viewController.modalTransitionStyle = .coverVertical
        return viewController
    }()

    // MARK: NSObject

    override init() {
        super.init()
        self.walletManager.accountInfoAndExchangeRatesDelegate = self
        self.walletManager.backupDelegate = self
        self.walletManager.historyDelegate = self
        observeSymbolChanges()
    }

    // MARK: Public Methodsº

    func startAfterWalletCreation() {
        window.rootViewController?.dismiss(animated: true, completion: nil)
        setupMainFlow(forced: true)
        window.rootViewController = slidingViewController
        tabControllerManager.dashBoardClicked(nil)
    }

    func syncPinKeyWithICloud() {
        // In order to login to wallet, we need to know:
        // GUID                 - To look up the wallet
        // SharedKey            - To be able to read/write to the wallet db record (payload, settings, etc)
        // EncryptedPinPassword - To decrypt the wallet
        // PinKey               - Used in conjunction with the user's PIN to retrieve decryption key to the EncryptedPinPassword (EncryptedWalletPassword)
        // PIN                  - Provided by the user or retrieved from secure enclave if Face/TouchID is enabled

        // In this method, we backup/restore the pinKey - which is essentially the identifier of the PIN.
        // Upon successful PIN authentication, we will backup/restore the remaining wallet details: guid, sharedKey, encryptedPinPassword.
        // The backup/restore of guid and sharedKey requires an encryption/decryption step when backing up and restoring respectively.
        // The key used to encrypt/decrypt the guid and sharedKey is provided in the response to a successful PIN auth attempt.

        guard !blockchainSettings.isPairedWithWallet else {
            // Wallet is Paired, we do not need to restore.
            // We will back up after pin authentication
            return
        }

        if blockchainSettings.pinKey == nil,
            blockchainSettings.encryptedPinPassword == nil,
            blockchainSettings.guid == nil,
            blockchainSettings.sharedKey == nil {

            credentialsStore.synchronize()

            // Attempt to restore the pinKey from iCloud
            if let pinData = credentialsStore.pinData() {
                blockchainSettings.pinKey = pinData.pinKey
                blockchainSettings.encryptedPinPassword = pinData.encryptedPinPassword
            }
        }
    }
    
    @objc func start() {
        appFeatureConfigurator.initialize()

        // Try to restore wallet details from iCloud
        syncPinKeyWithICloud()

        if blockchainSettings.guid != nil, blockchainSettings.sharedKey != nil {
            // Original flow
            AuthenticationCoordinator.shared.start()
        } else if blockchainSettings.pinKey != nil, blockchainSettings.encryptedPinPassword != nil {
            // iCloud restoration flow
            AuthenticationCoordinator.shared.start()
        } else {
            onboardingRouter.start()
        }
    }

    /// Shows an upgrade to HD wallet prompt if the user has a legacy wallet
    @objc func showHdUpgradeViewIfNeeded() {
        guard walletManager.wallet.isInitialized() else { return }
        guard !walletManager.wallet.didUpgradeToHd() else { return }
        showHdUpgradeView()
    }

    /// Shows the HD wallet upgrade view
    func showHdUpgradeView() {
        let storyboard = UIStoryboard(name: "Upgrade", bundle: nil)
        let upgradeViewController = storyboard.instantiateViewController(withIdentifier: "UpgradeViewController")
        upgradeViewController.modalPresentationStyle = .fullScreen
        upgradeViewController.modalTransitionStyle = .coverVertical
        UIApplication.shared.keyWindow?.rootViewController?.present(
            upgradeViewController,
            animated: true
        )
    }

    @discardableResult
    func setupMainFlow(forced: Bool) -> UIViewController {
        let setupAndReturnSideMenuController = { [unowned self] () -> UIViewController in
            self.setupTabControllerManager()
            self.setupSideMenuViewController()
            let viewController = ECSlidingViewController()
            viewController.underLeftViewController = self.sideMenuViewController
            viewController.topViewController = self.tabControllerManager
            self.slidingViewController = viewController
            self.tabControllerManager.loadViewIfNeeded()
            self.tabControllerManager.dashBoardClicked(nil)
            return viewController
        }
        
        if forced {
            return setupAndReturnSideMenuController()
        } else if let slidingViewController = slidingViewController {
            return slidingViewController
        } else {
            return setupAndReturnSideMenuController()
        }
    }

    private func setupSideMenuViewController() {
        let viewController = SideMenuViewController.makeFromStoryboard()
        viewController.delegate = self
        self.sideMenuViewController = viewController
    }
    
    private func setupTabControllerManager() {
        let tabControllerManager = TabControllerManager.makeFromStoryboard()
        self.tabControllerManager = tabControllerManager
    }

    func showSettingsView() {
        settingsRouterAPI = SettingsRouter(currencyRouting: self, tabSwapping: self)
        settingsRouterAPI?.presentSettings()
    }

    @objc func closeSideMenu() {
        guard let slidingViewController = slidingViewController else {
            return
        }
        guard slidingViewController.currentTopViewPosition != .centered else {
            return
        }
        slidingViewController.resetTopView(animated: true)
    }

    /// Reloads contained view controllers
    @objc func reload() {
        tabControllerManager.reload()
        accountsAndAddressesNavigationController.reload()
        sideMenuViewController?.reload()
        
        NotificationCenter.default.post(name: Constants.NotificationKeys.reloadToDismissViews, object: nil)

        // Legacy code for generating new addresses
        NotificationCenter.default.post(name: Constants.NotificationKeys.newAddress, object: nil)
    }

    /// Method to "cleanup" state when the app is backgrounded.
    func cleanupOnAppBackgrounded() {
        
        /// Keep going only if the user is logged in
        guard slidingViewController != nil else {
            return
        }
        tabControllerManager.hideSendAndReceiveKeyboards()
        tabControllerManager.dashBoardClicked(nil)
        closeSideMenu()
    }

    /// Observes symbol changes so that view controllers can reflect the new symbol
    private func observeSymbolChanges() {
        BlockchainSettings.App.shared.onSymbolLocalChanged = { [unowned self] _ in
            self.tabControllerManager.reloadSymbols()
            self.accountsAndAddressesNavigationController.reload()
            self.sideMenuViewController?.reload()
        }
    }

    func reloadAfterMultiAddressResponse() {
        if WalletManager.shared.wallet.didReceiveMessageForLastTransaction {
            WalletManager.shared.wallet.didReceiveMessageForLastTransaction = false
            if let transaction = WalletManager.shared.latestMultiAddressResponse?.transactions.firstObject as? Transaction {
                tabControllerManager.receiveBitcoinViewController?.paymentReceived(UInt64(abs(transaction.amount)))
            }
        }
        
        tabControllerManager.reloadAfterMultiAddressResponse()
        accountsAndAddressesNavigationController.reload()
        sideMenuViewController?.reload()

        NotificationCenter.default.post(name: Constants.NotificationKeys.reloadToDismissViews, object: nil)
        NotificationCenter.default.post(name: Constants.NotificationKeys.newAddress, object: nil)
        NotificationCenter.default.post(name: Constants.NotificationKeys.multiAddressResponseReload, object: nil)
    }
}

extension AppCoordinator: SideMenuViewControllerDelegate {
    func sideMenuViewController(_ viewController: SideMenuViewController, didTapOn item: SideMenuItem) {
        switch item {
        case .upgrade:
            handleUpgrade()
        case .backup:
            startBackupFlow()
        case .accountsAndAddresses:
            handleAccountsAndAddresses()
        case .settings:
            handleSettings()
        case .webLogin:
            handleWebLogin()
        case .support:
            handleSupport()
        case .airdrops:
            handleAirdrops()
        case .logout:
            handleLogout()
        case .buy:
            handleBuyCrypto()
        case .sell:
            handleSellCrypto()
        case .exchange:
            handleExchange()
        case .lockbox:
            let storyboard = UIStoryboard(name: "LockboxViewController", bundle: nil)
            let lockboxViewController = storyboard.instantiateViewController(withIdentifier: "LockboxViewController") as! LockboxViewController
            lockboxViewController.modalPresentationStyle = .fullScreen
            lockboxViewController.modalTransitionStyle = .coverVertical
            UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(lockboxViewController, animated: true)
        }
    }

    private func handleAirdrops() {
        airdropRouter.presentAirdropCenterScreen()
    }
    
    private func handleUpgrade() {
        AppCoordinator.shared.showHdUpgradeView()
    }

    func startBackupFlow() {
        backupRouter = BackupFundsCustodialRouter()
        backupRouter?.start()
    }

    private func handleAccountsAndAddresses() {
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(
            accountsAndAddressesNavigationController,
            animated: true
        ) { [weak self] in
            guard let strongSelf = self else { return }

            let wallet = strongSelf.walletManager.wallet

            guard strongSelf.accountsAndAddressesNavigationController.viewControllers.count == 1 &&
                wallet.didUpgradeToHd() &&
                wallet.getTotalBalanceForSpendableActiveLegacyAddresses() >= wallet.dust() &&
                strongSelf.accountsAndAddressesNavigationController.assetSelectorView().selectedAsset == .bitcoin else {
                    return
            }

            strongSelf.accountsAndAddressesNavigationController.alertUserToTransferAllFunds()
        }
    }

    private func handleSettings() {
        showSettingsView()
    }
    
    private func handleExchange() {
        ExchangeCoordinator.shared.start(from: tabControllerManager)
    }

    private func handleWebLogin() {
        let presenter = WebLoginScreenPresenter()
        let viewController = WebLoginScreenViewController(presenter: presenter)
        let navigationController = UINavigationController(rootViewController: viewController)
        UIApplication.shared.topMostViewController?.present(
            navigationController,
            animated: true
        )
    }

    private func handleSupport() {
        let title = String(format: LocalizationConstants.openArg, Constants.Url.blockchainSupport)
        let alert = UIAlertController(
            title: title,
            message: LocalizationConstants.youWillBeLeavingTheApp,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: LocalizationConstants.continueString, style: .default) { _ in
                guard let url = URL(string: Constants.Url.blockchainSupport) else { return }
                UIApplication.shared.open(url)
            }
        )
        alert.addAction(
            UIAlertAction(title: LocalizationConstants.cancel, style: .cancel)
        )
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(
            alert,
            animated: true
        )
    }

    private func handleLogout() {
        let alert = UIAlertController(
            title: LocalizationConstants.SideMenu.logout,
            message: LocalizationConstants.SideMenu.logoutConfirm,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: LocalizationConstants.okString, style: .default) { _ in
                AuthenticationCoordinator.shared.logout()
            }
        )
        alert.addAction(UIAlertAction(title: LocalizationConstants.cancel, style: .cancel))
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(
            alert,
            animated: true
        )
    }
    
    func clearOnLogout() {
        slidingViewController = nil
        sideMenuViewController = nil
    }

    /// Starts Buy Crypto flow.
    @objc func handleBuyCrypto() {
        let builder = BuySellUIKit.Builder(
            fiatCurrencyService: UserInformationServiceProvider.default.settings,
            serviceProvider: DataProvider.default.buySell,
            stateService: BuySellUIKit.StateService.make(),
            recordingProvider: RecordingProvider.default
        )
        buyRouter = BuySellUIKit.Router(builder: builder)
        buyRouter.start()
    }
    
    /// Starts Sell Crypto flow
    @objc func handleSellCrypto() {
        let builder = BuySellUIKit.SellBuilder(
            routerInteractor: SellRouterInteractor(
                accountSelectionService: DataProvider.default.buySell.accountSelectionService,
                uiUtilityProvider: UIUtilityProvider.default,
                kycTiersService: KYCServiceProvider.default.tiers,
                featureFetching: resolve()
            ),
            kycServiceProvider: resolve(),
            analyticsRecorder: resolve(),
            recorderProvider: RecordingProvider.default,
            userInformationProvider: resolve(),
            buySellServiceProvider: DataProvider.default.buySell,
            exchangeProvider: DataProvider.default.exchange,
            balanceProvider: DataProvider.default.balance
        )
        sellRouter = BuySellUIKit.SellRouter(kycRouter: KYCCoordinator.shared, builder: builder)
        sellRouter.load()
    }
    
    func startSimpleBuyAtLogin() {
        let stateService = BuySellUIKit.StateService.make()
        guard !stateService.cache[.hasShownIntroScreen] else {
            return
        }
        
        let builder = BuySellUIKit.Builder(
            fiatCurrencyService: UserInformationServiceProvider.default.settings,
            serviceProvider: DataProvider.default.buySell,
            stateService: stateService,
            recordingProvider: RecordingProvider.default
        )
        
        buyRouter = BuySellUIKit.Router(builder: builder)
        buyRouter.start()
    }
    
    func showFundTrasferDetails(fiatCurrency: FiatCurrency, isOriginDeposit: Bool) {
        let stateService = BuySellUIKit.StateService.make()
        let builder = BuySellUIKit.Builder(
            fiatCurrencyService: UserInformationServiceProvider.default.settings,
            serviceProvider: DataProvider.default.buySell,
            stateService: stateService,
            recordingProvider: RecordingProvider.default
        )
        
        buyRouter = BuySellUIKit.Router(builder: builder)
        buyRouter.setup(startImmediately: false)
        stateService.showFundsTransferDetails(
            for: fiatCurrency,
            isOriginDeposit: isOriginDeposit
        )
    }
}

// MARK: - QRScannerRouting

extension AppCoordinator: QRScannerRouting {
    func routeToQrScanner() {
        tabControllerManager.qrCodeButtonClicked()
    }
}

// MARK: - DrawerRouting

extension AppCoordinator: DrawerRouting {
    // Shows the side menu (i.e. ECSlidingViewController)
    @objc func toggleSideMenu() {
        // If the sideMenu is not shown, show it
        if slidingViewController.currentTopViewPosition == .centered {
            slidingViewController.anchorTopViewToRight(animated: true)
        } else {
            slidingViewController.resetTopView(animated: true)
        }
    }
}

extension AppCoordinator: WalletAccountInfoAndExchangeRatesDelegate {
    func didGetAccountInfoAndExchangeRates() {
        loadingViewPresenter.hide()
        reloadAfterMultiAddressResponse()
    }
}

extension AppCoordinator: WalletBackupDelegate {
    func didBackupWallet() {
        walletManager.wallet.getHistoryForAllAssets()
    }

    func didFailBackupWallet() {
        walletManager.wallet.getHistoryForAllAssets()
    }
}

extension AppCoordinator: WalletHistoryDelegate {
    func didFailGetHistory(error: String?) {
        guard let errorMessage = error, errorMessage.count > 0 else {
            AlertViewPresenter.shared.standardError(message: LocalizationConstants.Errors.noInternetConnectionPleaseCheckNetwork)
            return
        }
        AnalyticsService.shared.trackEvent(title: "btc_history_error", parameters: ["error": errorMessage])
        AlertViewPresenter.shared.standardError(message: LocalizationConstants.Errors.balancesGeneric)
    }

    func didFetchEthHistory() {
        loadingViewPresenter.hide()
        reload()
    }

    func didFetchBitcoinCashHistory() {
        loadingViewPresenter.hide()
        reload()
    }
}

// MARK: - TabSwapping

extension AppCoordinator: TabSwapping {
    func switchToSend() {
        tabControllerManager.sendCoinsClicked(nil)
    }
    
    func switchTabToSwap() {
        tabControllerManager.swapTapped(nil)
    }
    
    func switchTabToReceive() {
        tabControllerManager.receiveCoinClicked(nil)
    }
    
    func switchToActivity(currency: CryptoCurrency) {
        switch currency {
        case .algorand:
            tabControllerManager.showTransactionsAlgorand()
        case .bitcoin:
            tabControllerManager.showTransactionsBitcoin()
        case .bitcoinCash:
            tabControllerManager.showTransactionsBitcoinCash()
        case .ethereum:
            tabControllerManager.showTransactionsEther()
        case .pax:
            tabControllerManager.showTransactionsPax()
        case .stellar:
            tabControllerManager.showTransactionsStellar()
        case .tether:
            tabControllerManager.showTransactionsTether()
        }
    }
}

extension AppCoordinator: CurrencyRouting {
    func toSend(_ currency: CryptoCurrency) {
        tabControllerManager.showSend(currency.legacy)
    }
    
    func toReceive(_ currency: CryptoCurrency) {
        tabControllerManager.showReceive(currency.legacy)
    }
}

extension AppCoordinator: CashIdentityVerificationAnnouncementRouting {
    func showCashIdentityVerificationScreen() {
        let presenter = CashIdentityVerificationPresenter()
        let controller = CashIdentityVerificationViewController(presenter: presenter)
        tabControllerManager.tabViewController.showCashIdentityVerificatonController(controller)
    }
}

extension AppCoordinator: InterestIdentityVerificationAnnouncementRouting {
    func showInterestDashboardAnnouncementScreen(isKYCVerfied: Bool) {
        var presenter: InterestDashboardAnnouncementPresenting
        let router: InterestDashboardAnnouncementRouter = .init(
            topMostViewControllerProvider: resolve(),
            routerAPI: KYCCoordinator.shared,
            navigationRouter: NavigationRouter()
        )
        if isKYCVerfied {
            presenter = InterestDashboardAnnouncementScreenPresenter(
                router: router
            )
        } else {
            presenter = InterestIdentityVerificationScreenPresenter(
                router: router
            )
        }
        let controller = InterestDashboardAnnouncementViewController(presenter: presenter)
        tabControllerManager.tabViewController.showInterestIdentityVerificationScreen(controller)
    }
}

// MARK: - DevSupporting

extension AppCoordinator: DevSupporting {
    @objc func showDebugView(from presenter: DebugViewPresenter) {
        let debugViewController = DebugTableViewController()
        debugViewController.presenter = presenter
        let navigationController = UINavigationController(rootViewController: debugViewController)
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(navigationController, animated: true)
    }
}
