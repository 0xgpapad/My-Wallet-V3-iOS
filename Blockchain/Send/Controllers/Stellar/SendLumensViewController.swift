//
//  SendLumensViewController.swift
//  Blockchain
//
//  Created by Alex McGregor on 10/16/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import Foundation
import PlatformKit
import PlatformUIKit
import ToolKit

protocol SendXLMViewControllerDelegate: class {
    func onLoad()
    func onAppear()
    func onMemoTextSelection()
    func onMemoIDSelection()
    func onXLMEntry(_ value: String, latestPrice: Decimal)
    func onFiatEntry(_ value: String, latestPrice: Decimal)
    func onStellarAddressEntry(_ value: String?)
    func onPrimaryTapped(toAddress: String, amount: Decimal, feeInXlm: Decimal, memo: StellarMemoType?)
    func onConfirmPayTapped(_ paymentOperation: StellarPaymentOperation)
    func onMinimumBalanceInfoTapped()
    
    /// Invoked upon tapping the pit address button
    func onExchangeAddressButtonTapped()
    
    var sendingToExchange: Bool { get }
}

@objc class SendLumensViewController: BaseScreenViewController, BottomButtonContainerView {
    
    fileprivate static let topToStackView: CGFloat = 12.0
    fileprivate static let maximumMemoTextLength: Int = 28
    
    fileprivate var keyboardHeight: CGFloat {
        if DevicePresenter.type <= .compact {
            // SE, iPhone 8
            return 216
        } else {
            return 226
        }
    }
    
    // MARK: BottomButtonContainerView
    
    var originalBottomButtonConstraint: CGFloat!
    lazy var optionalOffset: CGFloat = {
        let window = UIApplication.shared.keyWindow
        let bottomSafeAreaInsets = window?.safeAreaInsets.bottom ?? 0
        return 8 - bottomSafeAreaInsets - originalBottomButtonConstraint
    }()
    @IBOutlet var layoutConstraintBottomButton: NSLayoutConstraint!
    
    @IBOutlet fileprivate var fromLabel: UILabel!
    @IBOutlet fileprivate var toLabel: UILabel!
    @IBOutlet fileprivate var walletNameLabel: UILabel!
    @IBOutlet fileprivate var feeLabel: UILabel!
    @IBOutlet fileprivate var feeAmountLabel: UILabel!
    @IBOutlet fileprivate var errorLabel: UILabel!
    @IBOutlet fileprivate var stellarSymbolLabel: UILabel!
    @IBOutlet fileprivate var fiatSymbolLabel: UILabel!
    @IBOutlet fileprivate var memoLabel: UILabel!
    @IBOutlet fileprivate var sendingToExchangeLabel: UILabel!
    @IBOutlet fileprivate var addMemoLabel: UILabel!
    
    @IBOutlet private var destinationAddressIndicatorLabel: UILabel!
    @IBOutlet private var exchangeAddressButton: UIButton!
    
    @IBOutlet fileprivate var stellarAddressField: UITextField!
    @IBOutlet fileprivate var stellarAmountField: UITextField!
    @IBOutlet fileprivate var fiatAmountField: UITextField!
    @IBOutlet fileprivate var memoTextField: UITextField!
    @IBOutlet fileprivate var memoIDTextField: UITextField!
    @IBOutlet fileprivate var sendingToAnExchangeStackView: UIStackView!
    
    fileprivate var inputFields: [UITextField] {
        [
            stellarAddressField,
            stellarAmountField,
            fiatAmountField,
            memoTextField,
            memoIDTextField
        ]
    }
    
    // MARK: Private IBOutlets (Other)
    
    @IBOutlet fileprivate var topToStackViewConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate var useMaxLabel: ActionableLabel!
    @IBOutlet fileprivate var primaryButtonContainer: PrimaryButtonContainer!
    @IBOutlet fileprivate var learnAboutStellarButton: UIButton!
    @IBOutlet fileprivate var bottomStackView: UIStackView!
    @IBOutlet fileprivate var memoSelectionTypeButton: UIButton!
    
    weak var delegate: SendXLMViewControllerDelegate?
    fileprivate var coordinator: SendXLMCoordinator!
    private let analyticsRecorder: AnalyticsEventRecording = resolve()
    private let alertViewPresenter: AlertViewPresenter = .shared
    fileprivate var trigger: ActionableTrigger?
    fileprivate var memo: StellarMemoType?
    fileprivate var toolbar: UIToolbar?

    // MARK: - Models
    private var pendingPaymentOperation: StellarPaymentOperation?
    private var latestPrice: Decimal? // fiat per whole unit
    private var xlmAmount: Decimal?
    private var xlmFee: Decimal?
    private var baseReserve: Decimal?
    
    private var qrScannerViewModel: QRCodeScannerViewModel<AddressQRCodeParser>?
    
    // MARK: Factory
    
    @objc class func make(with provider: StellarServiceProvider) -> SendLumensViewController {
        let controller = SendLumensViewController.makeFromStoryboard()
        controller.coordinator = SendXLMCoordinator(
            serviceProvider: provider,
            interface: controller,
            modelInterface: controller,
            exchangeAddressPresenter: SendExchangeAddressStatePresenter(assetType: .stellar)
        )
        return controller
    }
    
    // MARK: ViewUpdate
    
    enum PresentationUpdate {
        case activityIndicatorVisibility(Visibility)
        case errorLabelVisibility(Visibility)
        case learnAboutStellarButtonVisibility(Visibility)
        case actionableLabelVisibility(Visibility)
        case memoTextFieldVisibility(Visibility)
        case memoIDTextFieldVisibility(Visibility)
        case memoSelectionButtonVisibility(Visibility)
        case exchangeAddressButtonVisibility(Visibility)
        case memoRequiredDisclaimerVisibility(Visibility)
        case memoTextFieldShouldBeginEditing
        case memoIDFieldShouldBeginEditing
        case memoTextFieldText(String?)
        case errorLabelText(String)
        case feeAmountLabelText
        case stellarAddressText(String)
        case stellarAddressTextColor(UIColor)
        case xlmFieldTextColor(UIColor)
        case fiatFieldTextColor(UIColor)
        case actionableLabelTrigger(ActionableTrigger)
        case primaryButtonEnabled(Bool)
        case showPaymentConfirmation(StellarPaymentOperation)
        case hidePaymentConfirmation
        case paymentSuccess
        case stellarAmountText(String?)
        case fiatAmountText(String?)
        case fiatSymbolLabel(String?)
        case useExchangeAddress(String?)
        case showAlertForEnabling2FA
    }

    // MARK: Public Methods

    func scanQrCodeForDestinationAddress() {
        analyticsRecorder.record(event: AnalyticsEvents.Send.sendFormQrButtonClick(asset: .stellar))
        guard let scanner = QRCodeScanner() else { return }
        
        let parser = AddressQRCodeParser(assetType: .stellar)
        let textViewModel = AddressQRCodeTextViewModel()
        
        qrScannerViewModel = QRCodeScannerViewModel(
            parser: parser,
            additionalParsingOptions: .lax(routes: [.exchangeLinking]),
            textViewModel: textViewModel,
            scanner: scanner,
            completed: { [weak self] result in
                self?.handleAddressScan(result: result)
            }
        )
        
        let builder = QRCodeScannerViewControllerBuilder(viewModel: qrScannerViewModel)?
            .with(presentationType: .modal(dismissWithAnimation: false))
        
        guard let viewController = builder?.build() else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.navigationController?.present(viewController, animated: true, completion: nil)
        }
    }
    
    private func handleAddressScan(result: Result<AddressQRCodeParser.Address, AddressQRCodeParser.AddressQRCodeParserError>) {
        if case .success(let address) = result {
            stellarAddressField.insertText(address.payload.address)
            guard let amount = address.payload.amount else { return }
            stellarAmountField.insertText(amount)
        }
    }
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        originalBottomButtonConstraint = layoutConstraintBottomButton.constant
        setUpBottomButtonContainerView()
        setupMemoIDField()
        useMaxLabel.delegate = self
        memoTextField.delegate = self
        stellarAddressField.delegate = self
        primaryButtonContainer.isEnabled = true
        learnAboutStellarButton.titleLabel?.textAlignment = .center
        sendingToExchangeLabel.text = LocalizationConstants.Stellar.sendingToExchange
        addMemoLabel.text = LocalizationConstants.Stellar.addAMemo
        primaryButtonContainer.actionBlock = { [unowned self] in
            guard let toAddress = self.stellarAddressField.text else { return }
            guard let amount = self.xlmAmount else { return }
            guard let fee = self.xlmFee else { return }
            self.inputFields.forEach({ $0.resignFirstResponder() })
            self.delegate?.onPrimaryTapped(toAddress: toAddress, amount: amount, feeInXlm: fee, memo: self.memo)
        }
        memoIDTextField.placeholder = LocalizationConstants.Stellar.memoPlaceholder
        memoTextField.placeholder = LocalizationConstants.Stellar.memoPlaceholder
        delegate?.onLoad()
        setupAccessibility()
        setupNavigationBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        delegate?.onAppear()
    }

    private func setupNavigationBar() {
        set(barStyle: .lightContent(),
            leadingButtonStyle: .close,
            trailingButtonStyle: .qrCode)
    }

    override func navigationBarTrailingButtonPressed() {
        scanQrCodeForDestinationAddress()
    }

    private func setupAccessibility() {
        fromLabel.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.sourceAccountTitleLabel
        walletNameLabel.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.sourceAccountValueLabel
        
        toLabel.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.destinationAddressTitleLabel
        destinationAddressIndicatorLabel.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.destinationAddressIndicatorLabel
        stellarAddressField.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.destinationAddressTextField

        stellarSymbolLabel.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.cryptoTitleLabel
        stellarAmountField.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.cryptoAmountTextField
        
        fiatSymbolLabel.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.fiatTitleLabel
        fiatAmountField.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.fiatAmountTextField

        feeLabel.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.feesTitleLabel
        feeAmountLabel.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.feesValueLabel

        errorLabel.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.errorLabel
        
        useMaxLabel.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.maxAvailableLabel
        
        exchangeAddressButton.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.exchangeAddressButton
        
        memoSelectionTypeButton.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.Stellar.memoSelectionTypeButton
        memoIDTextField.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.Stellar.memoIDTextField
        memoTextField.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.Stellar.memoTextField
        memoLabel.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.Stellar.memoLabel
        
        learnAboutStellarButton.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.Stellar.moreInfoButton
        
        sendingToExchangeLabel.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.Stellar.sendingToExchangeLabel
        addMemoLabel.accessibilityIdentifier = AccessibilityIdentifiers.SendScreen.Stellar.addAMemoLabel
    }
    
    fileprivate func clearMemoField() {
        /// Users may change their mind and want to enter in a
        /// `Int` as their memo as opposed to a string value.
        /// So we do this when they have deleted everything in
        /// the memo field.
        [memoTextField, memoIDTextField].forEach({ $0?.resignFirstResponder() })
        memo = nil
        apply(updates: [.memoTextFieldVisibility(.visible),
                        .memoIDTextFieldVisibility(.hidden),
                        .memoSelectionButtonVisibility(.visible)])
    }
    
    fileprivate func setupMemoIDField() {
        toolbar = UIToolbar()
        toolbar?.sizeToFit()
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(resignMemoIDField))
        toolbar?.items = [doneButton]
        memoIDTextField.inputAccessoryView = toolbar
    }
    
    @objc func resignMemoIDField() {
        memoIDTextField.resignFirstResponder()
        
        /// If the user hasn't entered a value in the `memoIDTextField`
        /// we call `clearMemoField()` to reset the memo state. This allows
        /// users to see the action sheet again to select either `memoID` or
        /// `memoText`
        guard memoIDTextField.text?.count == 0 else { return }
        clearMemoField()
    }
    
    fileprivate func useMaxAttributes() -> [NSAttributedString.Key: Any] {
        let fontName = Constants.FontNames.montserratRegular
        let font = UIFont(name: fontName, size: 13.0) ?? UIFont.systemFont(ofSize: 13.0)
        return [.font: font,
                .foregroundColor: UIColor.darkGray]
    }
    
    fileprivate func useMaxActionAttributes() -> [NSAttributedString.Key: Any] {
        let fontName = Constants.FontNames.montserratRegular
        let font = UIFont(name: fontName, size: 13.0) ?? UIFont.systemFont(ofSize: 13.0)
        return [.font: font,
                .foregroundColor: UIColor.brandSecondary]
    }

    // swiftlint:disable function_body_length
    // swiftlint:disable:next cyclomatic_complexity
    fileprivate func apply(_ update: PresentationUpdate) {
        switch update {
        case .memoTextFieldText(let value):
            memoTextField.text = value
            guard let memo = value else {
                clearMemoField()
                return
            }
            self.memo = .text(memo)
        case .memoTextFieldVisibility(let visibility):
            memoTextField.alpha = visibility.defaultAlpha
        case .memoIDTextFieldVisibility(let visibility):
            memoIDTextField.alpha = visibility.defaultAlpha
        case .memoSelectionButtonVisibility(let visibility):
            memoSelectionTypeButton.alpha = visibility.defaultAlpha
            guard visibility == .visible else { return }
            memoIDTextField.text = nil
            memoTextField.text = nil
        case .memoRequiredDisclaimerVisibility(let visibility):
            let title = visibility.isHidden ? nil : LocalizationConstants.Stellar.required
            memoSelectionTypeButton.setTitle(title, for: .normal)
            sendingToAnExchangeStackView.isHidden = visibility.isHidden
            memoIDTextField.placeholder = visibility.isHidden ? LocalizationConstants.Stellar.memoPlaceholder : nil
            memoTextField.placeholder = visibility.isHidden ? LocalizationConstants.Stellar.memoPlaceholder : nil
        case .activityIndicatorVisibility(let visibility):
            primaryButtonContainer.isLoading = (visibility == .visible)
        case .errorLabelVisibility(let visibility):
            errorLabel.isHidden = visibility.isHidden
        case .learnAboutStellarButtonVisibility(let visibility):
            learnAboutStellarButton.isHidden = visibility.isHidden
        case .actionableLabelVisibility(let visibility):
            useMaxLabel.isHidden = visibility.isHidden
        case .memoTextFieldShouldBeginEditing:
            memoTextField.becomeFirstResponder()
        case .memoIDFieldShouldBeginEditing:
            memoIDTextField.becomeFirstResponder()
        case .errorLabelText(let value):
            errorLabel.text = value
        case .feeAmountLabelText:
            // TODO: move formatting outside of this file
            guard let price = latestPrice, let fee = xlmFee else { return }
            let assetType: CryptoCurrency = .stellar
            let xlmSymbol = assetType.displayCode
            let feeFormatted = NumberFormatter.stellarFormatter.string(from: NSDecimalNumber(decimal: fee)) ?? "\(fee)"
            let fiatCurrencySymbol = BlockchainSettings.App.shared.fiatCurrency.symbol
            let fiatAmount = price * fee
            let fiatFormatted = NumberFormatter.localCurrencyFormatter.string(from: NSDecimalNumber(decimal: fiatAmount)) ?? "\(fiatAmount)"
            let fiatText = fiatCurrencySymbol + fiatFormatted
            feeAmountLabel.text = "\(feeFormatted) \(xlmSymbol) (\(fiatText))"
        case .stellarAddressText(let value):
            stellarAddressField.text = value
        case .stellarAddressTextColor(let color):
            stellarAddressField.textColor = color
        case .xlmFieldTextColor(let color):
            stellarAmountField.textColor = color
        case .fiatFieldTextColor(let color):
            fiatAmountField.textColor = color
        case .actionableLabelTrigger(let trigger):
            self.trigger = trigger
            let primary = NSMutableAttributedString(
                string: trigger.primaryString,
                attributes: useMaxAttributes()
            )
            
            let CTA = NSAttributedString(
                string: " " + trigger.callToAction,
                attributes: useMaxActionAttributes()
            )
            
            primary.append(CTA)
            
            if let secondary = trigger.secondaryString {
                let trailing = NSMutableAttributedString(
                    string: " " + secondary,
                    attributes: useMaxAttributes()
                )
                primary.append(trailing)
            }
            
            useMaxLabel.attributedText = primary
        case .primaryButtonEnabled(let enabled):
            primaryButtonContainer.isEnabled = enabled
        case .paymentSuccess:
            showPaymentSuccess()
        case .showPaymentConfirmation(let paymentOperation):
            showPaymentConfirmation(paymentOperation: paymentOperation)
        case .hidePaymentConfirmation:
            ModalPresenter.shared.closeAllModals()
        case .stellarAmountText(let text):
            stellarAmountField.text = text
        case .fiatAmountText(let text):
            fiatAmountField.text = text
        case .fiatSymbolLabel(let text):
            fiatSymbolLabel.text = text
        case .exchangeAddressButtonVisibility(let visibility):
            exchangeAddressButton.isHidden = visibility.isHidden
        case .useExchangeAddress(let address):
            stellarAddressField.text = address
            if address == nil {
                exchangeAddressButton.setImage(UIImage(named: "exchange-icon-small"), for: .normal)
                stellarAddressField.isHidden = false
                destinationAddressIndicatorLabel.text = nil
            } else {
                exchangeAddressButton.setImage(UIImage(named: "cancel_icon"), for: .normal)
                stellarAddressField.isHidden = true
                destinationAddressIndicatorLabel.text = String(
                    format: LocalizationConstants.Exchange.Send.destination,
                    CryptoCurrency.stellar.displayCode
                )
            }
        case .showAlertForEnabling2FA:
            alertViewPresenter.standardNotify(
                title: LocalizationConstants.Errors.error, message: LocalizationConstants.Exchange.twoFactorNotEnabled
            )
        }
    }

    private func showPaymentSuccess() {
        let tabControllerManager = AppCoordinator.shared.tabControllerManager
        tabControllerManager?.showTransactions()
        AlertViewPresenter.shared.standardNotify(
            title: LocalizationConstants.success, message: LocalizationConstants.SendAsset.paymentSent
        )
    }

    private func showPaymentConfirmation(paymentOperation: StellarPaymentOperation) {
        self.pendingPaymentOperation = paymentOperation
        let viewModel = BCConfirmPaymentViewModel.initialize(with: paymentOperation, price: latestPrice)
        let confirmView = BCConfirmPaymentView(
            frame: view.frame,
            viewModel: viewModel,
            sendButtonFrame: primaryButtonContainer.frame
        )!
        confirmView.confirmDelegate = self
        ModalPresenter.shared.showModal(
            withContent: confirmView,
            closeType: ModalCloseTypeBack,
            showHeader: true,
            headerText: LocalizationConstants.SendAsset.confirmPayment
        )
    }
    
    // MARK: - User Actions
    
    @IBAction private func learnAboutStellarButtonTapped(_ sender: Any) {
        delegate?.onMinimumBalanceInfoTapped()
    }
    
    @IBAction private func memoSelectionTypeTapped(_ sender: UIButton) {
        let title = LocalizationConstants.Stellar.memoDescription
        let memoTextOption = LocalizationConstants.Stellar.memoText
        let memoTextID = LocalizationConstants.Stellar.memoID
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        
        [memoTextOption, memoTextID].forEach { option in
            let action = UIAlertAction(title: option, style: .default, handler: { [unowned self] _ in
                switch option {
                case memoTextOption:
                    self.delegate?.onMemoTextSelection()
                    
                case memoTextID:
                    self.delegate?.onMemoIDSelection()
                default:
                    break
                }
            })
            controller.addAction(action)
        }
        let cancel = UIAlertAction(title: LocalizationConstants.cancel, style: .cancel) { _ in
            controller.dismiss(animated: true, completion: nil)
        }
        controller.addAction(cancel)
        present(controller, animated: true, completion: nil)
    }
    
    @IBAction private func exchangeAddressButtonPressed() {
        delegate?.onExchangeAddressButtonTapped()
    }
}

extension SendLumensViewController: SendXLMInterface {
    func apply(updates: [PresentationUpdate]) {
        updates.forEach({ apply($0) })
    }

    func present(viewController: UIViewController) {
        navigationController?.present(viewController, animated: true, completion: nil)
    }
}

extension SendLumensViewController: ConfirmPaymentViewDelegate {
    func confirmButtonDidTap(_ note: String?) {
        guard let paymentOperation = pendingPaymentOperation else {
            Logger.shared.warning("No pending payment operation")
            return
        }
        delegate?.onConfirmPayTapped(paymentOperation)
    }

    func feeInformationButtonClicked() {
        // TODO
    }
}

extension SendLumensViewController: ActionableLabelDelegate {
    func targetRange(_ label: ActionableLabel) -> NSRange? {
        trigger?.actionRange()
    }

    func actionRequestingExecution(label: ActionableLabel) {
        guard let trigger = trigger else { return }
        analyticsRecorder.record(event: AnalyticsEvents.Send.sendFormUseBalanceClick(asset: .stellar))
        trigger.execute()
    }
}

extension BCConfirmPaymentViewModel {
    static func initialize(
        with paymentOperation: StellarPaymentOperation,
        price: Decimal?
    ) -> BCConfirmPaymentViewModel {
        // TODO: Refactor, move formatting out
        let assetType: CryptoCurrency = .stellar
        let amountXlm = paymentOperation.amountInXlm
        let feeXlm = paymentOperation.feeInXlm

        let amountXlmDecimalNumber = NSDecimalNumber(decimal: amountXlm)
        let amountXlmString = NumberFormatter.stellarFormatter.string(from: amountXlmDecimalNumber) ?? "\(amountXlm)"
        let amountXlmStringWithSymbol = amountXlmString.appendAssetSymbol(for: assetType)

        let feeXlmDecimalNumber = NSDecimalNumber(decimal: paymentOperation.feeInXlm)
        let feeXlmString = NumberFormatter.stellarFormatter.string(from: feeXlmDecimalNumber) ?? "\(feeXlm)"
        let feeXlmStringWithSymbol = feeXlmString.appendAssetSymbol(for: assetType)

        let totalXlmDecimalNumber = NSDecimalNumber(decimal: amountXlm + feeXlm)
        let totalXlmString = NumberFormatter.stellarFormatter.string(from: totalXlmDecimalNumber) ?? "\(amountXlm)"
        let totalXlmStringWithSymbol = totalXlmString.appendAssetSymbol(for: assetType)

        let fiatTotalAmountText: String
        let cryptoWithFiatAmountText: String
        let amountWithFiatFeeText: String

        if let decimalPrice = price {
            fiatTotalAmountText = NumberFormatter.localCurrencyAmount(
                fromAmount: amountXlm + feeXlm,
                fiatPerAmount: decimalPrice
            ).appendCurrencySymbol()
            cryptoWithFiatAmountText = NumberFormatter.formattedAssetAndFiatAmountWithSymbols(
                fromAmount: amountXlm,
                fiatPerAmount: decimalPrice,
                assetType: .stellar
            )
            amountWithFiatFeeText = NumberFormatter.formattedAssetAndFiatAmountWithSymbols(
                fromAmount: feeXlm,
                fiatPerAmount: decimalPrice,
                assetType: .stellar
            )
        } else {
            fiatTotalAmountText = ""
            cryptoWithFiatAmountText = amountXlmStringWithSymbol
            amountWithFiatFeeText = feeXlmStringWithSymbol
        }
        
        return BCConfirmPaymentViewModel(
            from: paymentOperation.sourceAccount.label ?? "",
            destinationDisplayAddress: paymentOperation.destinationAccountDisplayName,
            destinationRawAddress: paymentOperation.destinationAccountId,
            totalAmountText: totalXlmStringWithSymbol,
            fiatTotalAmountText: fiatTotalAmountText,
            cryptoWithFiatAmountText: cryptoWithFiatAmountText,
            amountWithFiatFeeText: amountWithFiatFeeText,
            buttonTitle: LocalizationConstants.SendAsset.send,
            showDescription: paymentOperation.memo != nil,
            surgeIsOccurring: false,
            showsFeeInformationButton: false,
            noteText: paymentOperation.memo?.displayValue,
            warningText: nil,
            descriptionTitle: LocalizationConstants.Stellar.memoTitle
        )
    }
}

extension SendLumensViewController: SendXLMModelInterface {
    func updateFee(_ value: Decimal) {
        xlmFee = value
    }

    func updatePrice(_ value: Decimal) {
        latestPrice = value
    }

    func updateXLMAmount(_ value: Decimal?) {
        xlmAmount = value
    }

    func updateBaseReserve(_ value: Decimal?) {
        baseReserve = value
    }
}

extension SendLumensViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if [memoIDTextField, memoTextField].contains(textField), memo == nil {
            clearMemoField()
        }
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard DevicePresenter.type <= .compact else { return }
        // SE, iPhone 8
        guard [memoTextField, memoIDTextField].contains(textField) else { return }
        let toolbarHeight = toolbar?.frame.height ?? 0.0
        let primaryButtonOffset = originalBottomButtonConstraint +
            optionalOffset +
            keyboardHeight +
            primaryButtonContainer.frame.size.height +
            toolbarHeight
        
        let height = view.bounds.height
        let bottomStackViewMaxY = bottomStackView.frame.maxY
        let offset = (height - bottomStackViewMaxY) - primaryButtonOffset
        
        guard topToStackViewConstraint.constant != offset else { return }
        topToStackViewConstraint.constant = offset
        view.setNeedsLayout()
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard topToStackViewConstraint.constant != SendLumensViewController.topToStackView else { return }
        topToStackViewConstraint.constant = SendLumensViewController.topToStackView
        view.setNeedsLayout()
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        guard textField == stellarAddressField else { return true }
        delegate?.onStellarAddressEntry(nil)
        return true
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        guard [memoTextField].contains(textField) else { return true }
        /// If the user is sending XLM funds to the Exchange, we don't
        /// want them to change the memo value, otherwise they
        /// risk losing their funds. 
        guard delegate?.sendingToExchange == false else { return false }
        return true
    }
    
    // swiftlint:disable:next cyclomatic_complexity
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if inputFields.contains(textField) {
            switch textField {
            case memoTextField:
                guard let text = textField.text else { return true }
                guard let current = Range(range, in: text) else { return true }
                let value = text.replacingCharacters(in: current, with: string)
                if value.count == 0 {
                    clearMemoField()
                    return true
                }
                let count = text.utf8.count + string.utf8.count - range.length
                guard count <= SendLumensViewController.maximumMemoTextLength else { return false }
                memo = .text(value)
                
            case memoIDTextField:
                guard let text = textField.text else { return true }
                guard let range = Range(range, in: text) else { return true }
                let value = text.replacingCharacters(in: range, with: string)
                if value.count == 0 {
                    clearMemoField()
                    return true
                }
                guard let identifier = Int(value) else { return false }
                if identifier <= Int64.max {
                    memo = .identifier(identifier)
                    return true
                } else {
                    return false
                }
            case stellarAddressField:
                return addressField(
                    textField,
                    shouldChangeCharactersIn: range,
                    replacementString: string
                )
            case fiatAmountField, stellarAmountField:
                return amountField(
                    textField,
                    shouldChangeCharactersIn: range,
                    replacementString: string
                )
            default:
                return true
            }
        }
        return true
    }
}

// MARK: - Text Field handling
extension SendLumensViewController {

    func amountField(_ amountField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let text = amountField.text,
            let textRange = Range(range, in: text) {
            let newString = text.replacingCharacters(in: textRange, with: string)

            var maxDecimalPlaces: Int?
            if amountField == stellarAmountField {
                maxDecimalPlaces = CryptoCurrency.stellar.maxDisplayableDecimalPlaces
            } else if amountField == fiatAmountField {
                maxDecimalPlaces = NumberFormatter.localCurrencyFractionDigits
            }

            guard let decimalPlaces = maxDecimalPlaces else {
                Logger.shared.error("Unhandled textfield")
                return true
            }

            let amountDelegate = AmountTextFieldDelegate(maxDecimalPlaces: decimalPlaces)
            let isInputValid = amountDelegate.textField(amountField, shouldChangeCharactersIn: range, replacementString: string)
            if !isInputValid {
                return false
            }

            guard let price = latestPrice else { return true }
            if amountField == stellarAmountField {
                delegate?.onXLMEntry(newString, latestPrice: price)
            } else if amountField == fiatAmountField {
                delegate?.onFiatEntry(newString, latestPrice: price)
            }
        }
        return true
    }

    func addressField(_ addressField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = addressField.text else { return true }
        
        let replacementInput = (text as NSString).replacingCharacters(in: range, with: string)
        
        if addressField == stellarAddressField {
            delegate?.onStellarAddressEntry(replacementInput)
        }
        return true
    }
}
