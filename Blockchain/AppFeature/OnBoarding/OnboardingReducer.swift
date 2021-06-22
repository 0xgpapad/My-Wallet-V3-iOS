// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import AuthenticationUIKit
import Combine
import ComposableArchitecture
import PlatformKit
import PlatformUIKit
import SettingsKit

public enum Onboarding {
    public enum Alert: Equatable {
        case walletAuthentication(AuthenticationError)
    }

    public enum Action: Equatable {
        case start
        case pin(PinCore.Action)
        case walletUpgrade(WalletUpgrade.Action)
        case passwordScreen(PasswordRequired.Action)
        case welcomeScreen(AuthenticationAction)
        case forgetWallet
    }

    public struct State: Equatable {
        var pinState: PinCore.State? = .init()
        var walletUpgradeState: WalletUpgrade.State?
        var passwordScreen: PasswordRequired.State?
        var authenticationState: AuthenticationState?
        var displayAlert: Alert?
    }

    public struct Environment {
        var blockchainSettings: BlockchainSettings.App
        var walletManager: WalletManager
        var alertPresenter: AlertViewPresenterAPI
        var mainQueue: AnySchedulerOf<DispatchQueue>
    }
}

/// The reducer responsible for handing Pin screen and Login/Onboarding screen related action and state.
let onBoardingReducer = Reducer<Onboarding.State, Onboarding.Action, Onboarding.Environment>.combine(
    authenticationReducer
        .optional()
        .pullback(
            state: \.authenticationState,
            action: /Onboarding.Action.welcomeScreen,
            environment: {
                AuthenticationEnvironment(
                    mainQueue: $0.mainQueue
                )
            }
        ),
    pinReducer
        .optional()
        .pullback(
            state: \.pinState,
            action: /Onboarding.Action.pin,
            environment: {
                PinCore.Environment(
                    walletManager: $0.walletManager,
                    appSettings: $0.blockchainSettings,
                    alertPresenter: $0.alertPresenter
                )
            }
        ),
    passwordRequiredReducer
        .optional()
        .pullback(
            state: \.passwordScreen,
            action: /Onboarding.Action.passwordScreen,
            environment: { _ in
                PasswordRequired.Environment()
            }
        ),
    walletUpgradeReducer
            .optional()
            .pullback(
                state: \.walletUpgradeState,
                action: /Onboarding.Action.walletUpgrade,
                environment: { _ in
                    WalletUpgrade.Environment()
                }
            ),
    Reducer<Onboarding.State, Onboarding.Action, Onboarding.Environment> { state, action, environment in
        switch action {
        case .start:
            return decideFlow(
                state: &state,
                blockchainSettings: environment.blockchainSettings
            )
        case .pin:
            return .none
        case .welcomeScreen:
            return .none
        case .walletUpgrade(.begin):
            return .none
        case .walletUpgrade:
            return .none
        case .passwordScreen(.forgetWallet),
             .forgetWallet:
            state.passwordScreen = nil
            state.pinState = nil
            state.authenticationState = .init()
            return Effect(value: .welcomeScreen(.start))
        case .passwordScreen:
            return .none
        }
    }
)

// MARK: - Internal Methods

func decideFlow(state: inout Onboarding.State, blockchainSettings: BlockchainSettings.App) -> Effect<Onboarding.Action, Never> {
    if blockchainSettings.guid != nil, blockchainSettings.sharedKey != nil {
        // Original flow
        if blockchainSettings.isPinSet {
            state.pinState = .init()
            state.passwordScreen = nil
            return Effect(value: .pin(.authenticate))
        } else {
            state.pinState = nil
            state.passwordScreen = .init()
            return Effect(value: .passwordScreen(.start))
        }
    } else if blockchainSettings.pinKey != nil, blockchainSettings.encryptedPinPassword != nil {
        // iCloud restoration flow
        if blockchainSettings.isPinSet {
            state.pinState = .init()
            state.passwordScreen = nil
            return Effect(value: .pin(.authenticate))
        } else {
            state.pinState = nil
            state.passwordScreen = .init()
            return Effect(value: .passwordScreen(.start))
        }
    } else {
        state.pinState = nil
        state.passwordScreen = nil
        state.authenticationState = .init()
        return Effect(value: .welcomeScreen(.start))
    }
}
