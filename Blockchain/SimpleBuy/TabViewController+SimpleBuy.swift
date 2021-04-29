// Copyright © Blockchain Luxembourg S.A. All rights reserved.

extension TabViewController {
    func showCashIdentityVerificatonController(_ controller: CashIdentityVerificationViewController) {
        controller.transitioningDelegate = sheetPresenter
        controller.modalPresentationStyle = .custom
        controller.isModalInPresentation = true
        present(controller, animated: true, completion: nil)
    }
}
