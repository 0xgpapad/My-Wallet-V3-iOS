//
//  RegisterWalletScreenPresenter.swift
//  Blockchain
//
//  Created by AlexM on 10/3/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import PlatformKit
import PlatformUIKit
import RxCocoa
import RxRelay
import RxSwift

/// A presentation layer for wallet creation
final class RegisterWalletScreenPresenter {
    
    /// Typealias to lessen verbosity
    private typealias LocalizedString = LocalizationConstants.Onboarding.CreateWalletScreen
    
    // MARK: - Exposed Properties
    
    var titleStyle: Screen.Style.TitleView {
        switch type {
        case .default:
            return .text(value: LocalizedString.title)
        case .recovery:
            let title = LocalizationConstants.Onboarding.RecoverFunds.title
            return .text(value: title)
        }
    }
    
    let navBarStyle = Screen.Style.Bar.lightContent()
    let emailTextFieldViewModel: TextFieldViewModel
    let passwordTextFieldViewModel: PasswordTextFieldViewModel
    let confirmPasswordTextFieldViewModel: PasswordTextFieldViewModel
    let buttonViewModel = ButtonViewModel.primary(
        with: LocalizedString.button
    )
    let termsOfUseTextViewModel: InteractableTextViewModel = {
        let font = UIFont.main(.medium, 12)
        return InteractableTextViewModel(
            inputs: [
                .text(string: LocalizedString.TermsOfUse.prefix),
                .url(string: LocalizedString.TermsOfUse.termsOfServiceLink,
                     url: Constants.Url.termsOfService),
                .text(string: LocalizedString.TermsOfUse.linkDelimiter),
                .url(string: LocalizedString.TermsOfUse.privacyPolicyLink,
                     url: Constants.Url.privacyPolicy)
            ],
            textStyle: .init(color: .descriptionText, font: font),
            linkStyle: .init(color: .linkableText, font: font)
        )
    }()
    
    /// The total state of the presentation
    var state: Driver<FormPresentationState> {
        stateRelay.asDriver()
    }

    let webViewLaunchRelay = PublishRelay<URL>()
    
    // MARK: - Injected Properties

    private let alertPresenter: AlertViewPresenter
    private let loadingViewPresenter: LoadingViewPresenting
    private let interactor: RegisterWalletScreenInteracting
    private let type: RegistrationType
    
    // MARK: - Accessors
    
    private let stateReducer = FormPresentationStateReducer()
    private let stateRelay = BehaviorRelay<FormPresentationState>(value: .invalid(.emptyTextField))
    private let disposeBag = DisposeBag()
    
    // MARK: - Setup
    
    init(alertPresenter: AlertViewPresenter = .shared,
         loadingViewPresenter: LoadingViewPresenting = resolve(),
         interactor: RegisterWalletScreenInteracting,
         type: RegistrationType = .default) {
        self.alertPresenter = alertPresenter
        self.loadingViewPresenter = loadingViewPresenter
        self.interactor = interactor
        self.type = type
        let newPasswordValidator = TextValidationFactory.Password.new
        let confirmNewPasswordValidator = TextValidationFactory.Password.new
        let textMatchValidator = CollectionTextMatchValidator(
            newPasswordValidator,
            confirmNewPasswordValidator,
            invalidReason: LocalizationConstants.TextField.Gesture.passwordMismatch
        )
        
        emailTextFieldViewModel = TextFieldViewModel(
            with: .email,
            validator: TextValidationFactory.Info.email,
            messageRecorder: CrashlyticsRecorder()
        )
        
        passwordTextFieldViewModel = PasswordTextFieldViewModel(
            with: .newPassword,
            passwordValidator: newPasswordValidator,
            textMatchValidator: textMatchValidator,
            messageRecorder: CrashlyticsRecorder()
        )
        
        confirmPasswordTextFieldViewModel = PasswordTextFieldViewModel(
            with: .confirmNewPassword,
            passwordValidator: confirmNewPasswordValidator,
            textMatchValidator: textMatchValidator,
            messageRecorder: CrashlyticsRecorder()
        )
        
        let latestStatesObservable = Observable
            .combineLatest(
                emailTextFieldViewModel.state,
                passwordTextFieldViewModel.state,
                confirmPasswordTextFieldViewModel.state
            )
        
        let stateObservable = latestStatesObservable
            .map(weak: self) { (self, payload) -> FormPresentationState in
                try self.stateReducer.reduce(states: [payload.0, payload.1, payload.2])
            }
            /// Should never get to `catchErrorJustReturn`.
            .catchErrorJustReturn(.invalid(.invalidTextField))
            .share(replay: 1)
        
        // Bind state to relay
        stateObservable
            .bindAndCatch(to: stateRelay)
            .disposed(by: disposeBag)
        
        // Bind state to button state to decide if it's enabled
        stateObservable
            .map { $0.isValid }
            .bindAndCatch(to: buttonViewModel.isEnabledRelay)
            .disposed(by: disposeBag)
        
        // Extract the latest valid values to the interaction layer
        latestStatesObservable
            .compactMap { (emailState, passwordState, _) -> WalletRegistrationContent? in
                guard let email = emailState.value, let password = passwordState.value else { return nil }
                return .init(email: email, password: password)
            }
            .bindAndCatch(to: interactor.contentStateRelay)
            .disposed(by: disposeBag)
        
        // Bind taps to the web view
        termsOfUseTextViewModel.tap
            .map { $0.url }
            .bindAndCatch(to: webViewLaunchRelay)
            .disposed(by: disposeBag)
        
        // Bind taps on the main button to wallet creation
        buttonViewModel.tapRelay
            .bind { [unowned self] in
                self.execute()
            }
            .disposed(by: disposeBag)
        
        interactor.error
            .bind { [weak self] error in
                self?.handleInteraction(error: error)
            }
            .disposed(by: disposeBag)
    }
    
    func viewDidLoad() {
        emailTextFieldViewModel.focusRelay.accept(.on)
    }
    
    /// Calls the interactor to initiate wallet creation
    private func execute() {
        loadingViewPresenter.showCircular(with: LocalizationConstants.Authentication.loadingWallet)
        do {
            try interactor.execute()
        } catch { // TODO: Handle additional errors
            alertPresenter.internetConnection()
            loadingViewPresenter.hide()
        }
    }
    
    /// Handles interaction errors by displaying an alert
    private func handleInteraction(error: String) {
        loadingViewPresenter.hide()
        alertPresenter.notify(
            content: .init(
                title: LocalizationConstants.Errors.error,
                message: error
            )
        )
    }
}
