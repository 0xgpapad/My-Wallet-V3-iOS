//
//  DepositRootBuilder.swift
//  TransactionUIKit
//
//  Created by Alex McGregor on 4/28/21.
//  Copyright © 2021 Blockchain Luxembourg S.A. All rights reserved.
//

import RIBs

// MARK: - Builder

public protocol DepositRootBuildable: Buildable {
    func build() -> DepositRootRouting
}

public final class DepositRootBuilder: DepositRootBuildable {

    public init() { }

    public func build() -> DepositRootRouting {
        let viewController = DepositRootViewController()
        let interactor = DepositRootInteractor()
        interactor.listener = interactor
        let router = DepositRootRouter(interactor: interactor, viewController: viewController)
        interactor.router = router
        return router
    }
}
