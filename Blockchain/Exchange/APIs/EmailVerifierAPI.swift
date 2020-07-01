//
//  EmailVerifierAPI.swift
//  Blockchain
//
//  Created by AlexM on 7/9/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import PlatformUIKit
import RxSwift

protocol EmailVerifierAPI {
    func sendVerificationEmail(to email: String, contextParameter: FlowContext?) -> Completable
    func pollWalletSettings() -> Observable<WalletSettings>
    func waitForEmailVerification() -> Observable<Bool>
    var userEmail: Single<Email> { get }
}

protocol EmailVerificationInterface: class {
    func updateLoadingViewVisibility(_ visibility: Visibility)
    func showError(message: String)
    func sendEmailVerificationSuccess()
}
