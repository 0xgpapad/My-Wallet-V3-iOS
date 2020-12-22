//
//  SelectPaymentMethodBuilder.swift
//  BuySellUIKit
//
//  Created by Dimitrios Chatzieleftheriou on 03/12/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RIBs

// MARK: - Builder

protocol SelectPaymentMethodBuildable {
    func build(listener: SelectPaymentMethodListener) -> SelectPaymentMethodRouting
}

final class SelectPaymentMethodBuilder: SelectPaymentMethodBuildable {

    private let stateService: StateServiceAPI

    init(stateService: StateServiceAPI) {
        self.stateService = stateService
    }

    func build(listener: SelectPaymentMethodListener) -> SelectPaymentMethodRouting {
        let viewController = SelectPaymentMethodViewController()
        if #available(iOS 13.0, *) {
            viewController.isModalInPresentation = true
        }
        let selectPaymentMethodService = SelectPaymentMethodService()
        let interactor = SelectPaymentMethodInteractor(presenter: viewController,
                                                       paymentMethodService: selectPaymentMethodService)
        interactor.listener = listener
        return SelectPaymentMethodRouter(interactor: interactor, viewController: viewController)
    }
}
