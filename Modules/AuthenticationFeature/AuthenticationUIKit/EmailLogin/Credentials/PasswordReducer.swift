// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import ComposableArchitecture

// MARK: - Type

public enum PasswordAction: Equatable {
    case didChangePassword(String)
    case incorrectPasswordErrorVisibility(Bool)
}

// MARK: - Properties

struct PasswordState: Equatable {
    var password: String
    var isPasswordIncorrect: Bool

    init() {
        password = ""
        isPasswordIncorrect = false
    }
}

let passwordReducer = Reducer<
    PasswordState,
    PasswordAction,
    CredentialsEnvironment
> {
    state, action, _ in
    switch action {
    case .didChangePassword(let password):
        state.password = password
        return .none
    case .incorrectPasswordErrorVisibility(let isVisible):
        state.isPasswordIncorrect = isVisible
        return .none
    }
}
