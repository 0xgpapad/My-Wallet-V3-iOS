//
//  ExchangeListPresenter.swift
//  Blockchain
//
//  Created by Alex McGregor on 8/24/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import PlatformKit
import ToolKit

class ExchangeListPresenter {
    fileprivate let interactor: ExchangeListInput
    weak var interface: ExchangeListInterface?
    
    init(interactor: ExchangeListInput) {
        self.interactor = interactor
    }
}

extension ExchangeListPresenter: ExchangeListDelegate {
    func onLoaded() {
        interface?.enablePullToRefresh()
        interface?.refreshControlVisibility(.visible)
        interactor.fetchAllTrades()
    }
    
    func onDisappear() {
        interactor.cancel()
    }
    
    func onNextPageRequest(_ identifier: String) {
        guard interactor.canPage() else { return }
        interface?.paginationActivityIndicatorVisibility(.visible)
        interactor.nextPageBefore(identifier: identifier)
    }
    
    func onPullToRefresh() {
        interface?.refreshControlVisibility(.visible)
        interactor.refresh()
    }

    func onTradeCellTapped(_ trade: ExchangeTradeCellModel) {
        interface?.showTradeDetails(trade: trade)
    }
}

extension ExchangeListPresenter: ExchangeListOutput {
    func willApplyUpdate() {
        // TODO:
    }
    
    func didApplyUpdate() {
        // TODO:
    }
    
    func loadedTrades(_ trades: [ExchangeTradeCellModel]) {
        interface?.refreshControlVisibility(.hidden)
        interface?.display(results: trades)
    }
    
    func appendTrades(_ trades: [ExchangeTradeCellModel]) {
        interface?.paginationActivityIndicatorVisibility(.hidden)
        interface?.append(results: trades)
    }
    
    func refreshedTrades(_ trades: [ExchangeTradeCellModel]) {
        interface?.refreshControlVisibility(.hidden)
        interface?.display(results: trades)
    }
    
    func tradeWithIdentifier(_ identifier: String) -> ExchangeTradeCellModel? {
        interactor.tradeSelectedWith(identifier: identifier)
    }
    
    func tradeFetchFailed(error: Error?) {
        Logger.shared.error(error?.localizedDescription ?? "Unknown error")
        interface?.refreshControlVisibility(.hidden)
        interface?.showError(message: LocalizationConstants.Swap.exchangeListError)
    }
}
