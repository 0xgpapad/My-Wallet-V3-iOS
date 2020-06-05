//
//  SimpleBuyRouterAPI.swift
//  BuySellUIKit
//
//  Created by Daniel Huri on 04/06/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

public protocol SimpleBuyRouterAPI: class {
    func start()
    func next(to state: SimpleBuyStateService.State)
    func previous(from state: SimpleBuyStateService.State)
    func showCryptoSelectionScreen()
}
