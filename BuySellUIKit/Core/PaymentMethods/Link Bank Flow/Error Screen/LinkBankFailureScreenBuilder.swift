//
//  LinkBankFailureScreenBuilder.swift
//  BuySellUIKit
//
//  Created by Dimitrios Chatzieleftheriou on 23/12/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformUIKit
import RIBs

protocol LinkBankFailureScreenBuildable {
    func build(withListener listener: LinkBankFailureScreenListener) -> LinkBankFailureScreenRouting
}

final class LinkBankFailureScreenBuilder: LinkBankFailureScreenBuildable {

    func build(withListener listener: LinkBankFailureScreenListener) -> LinkBankFailureScreenRouting {
        let interactor = LinkBankFailureScreenInteractor()
        let presenter = LinkBankFailureScreenPresenter(interactor: interactor)
        let viewController = PendingStateViewController(presenter: presenter)
        if #available(iOS 13.0, *) {
            viewController.isModalInPresentation = true
        }
        interactor.listener = listener
        return LinkBankFailureScreenRouter(interactor: interactor, viewController: viewController)
    }
}

extension PendingStateViewController: LinkBankFailureScreenViewControllable { }
