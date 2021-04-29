//
//  LinkedBanksBuilder.swift
//  TransactionUIKit
//
//  Created by Alex McGregor on 4/28/21.
//  Copyright © 2021 Blockchain Luxembourg S.A. All rights reserved.
//

import RIBs

// MARK: - Builder

protocol LinkedBanksBuildable: Buildable {
    func build(withListener listener: LinkedBanksListener) -> LinkedBanksRouting
}

final class LinkedBanksBuilder: LinkedBanksBuildable {

    public init() { }

    func build(withListener listener: LinkedBanksListener) -> LinkedBanksRouting {
        let viewController = LinkedBanksViewController()
        let interactor = LinkedBanksInteractor()
        interactor.listener = listener
        let router = LinkedBanksRouter(interactor: interactor, viewController: viewController)
        interactor.router = router
        return router
    }
}
