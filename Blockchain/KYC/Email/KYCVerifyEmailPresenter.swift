//
//  KYCVerifyEmailPresenter.swift
//  Blockchain
//
//  Created by Chris Arriola on 12/8/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift

typealias EmailAddress = String

protocol KYCVerifyEmailView: class {
    func showLoadingView()

    func sendEmailVerificationSuccess()

    func showError(message: String)

    func hideLoadingView()
}

protocol KYCConfirmEmailView: KYCVerifyEmailView {
    func emailVerifiedSuccess()
}

class KYCVerifyEmailPresenter {

    private weak var view: KYCVerifyEmailView?
    private let interactor: KYCVerifyEmailInteractor
    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    init(view: KYCVerifyEmailView, interactor: KYCVerifyEmailInteractor = KYCVerifyEmailInteractor()) {
        self.view = view
        self.interactor = interactor
    }

    func listenForEmailConfirmation() {
//        let disposable = interactor.pollEmailVerification()
        let disposable = interactor.debugPollEmailVerification()
            .subscribeOn(MainScheduler.asyncInstance)
            .distinctUntilChanged()
            .filter { $0 }
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                guard let confirmView = strongSelf.view as? KYCConfirmEmailView else {
                    return
                }
                confirmView.emailVerifiedSuccess()
            })
        disposables.insertWithDiscardableResult(disposable)
    }

    func sendVerificationEmail(to email: EmailAddress) {
        view?.showLoadingView()
        let disposable = interactor.sendVerificationEmail(to: email)
            .subscribeOn(MainScheduler.asyncInstance)
            .observeOn(MainScheduler.instance)
            .do(onDispose: { [weak self] in
                self?.view?.hideLoadingView()
            })
            .subscribe(onCompleted: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.view?.sendEmailVerificationSuccess()
            }, onError: { [weak self] error in
                Logger.shared.error("Failed to send verification email: \(error.localizedDescription)")
                guard let strongSelf = self else {
                    return
                }
                strongSelf.view?.showError(message: LocalizationConstants.KYC.failedToSendVerificationEmail)
            })
        disposables.insertWithDiscardableResult(disposable)
    }
}
