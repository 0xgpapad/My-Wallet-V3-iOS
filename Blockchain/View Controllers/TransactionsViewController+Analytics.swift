//
//  TransactionsViewController+Analytics.swift
//  Blockchain
//
//  Created by Daniel Huri on 07/10/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import ToolKit
import ToolKit
import PlatformKit

extension TransactionsViewController {
    
    @objc
    func reportTransactionClick(asset: LegacyAssetType) {
        let asset = CryptoCurrency(from: asset)
        reportTransactionClick(asset: asset)
    }
    
    func reportTransactionClick(asset: CryptoCurrency) {
        AnalyticsEventRecorder.shared.record(
            event: AnalyticsEvents.Transactions.transactionsListItemClick(asset: asset)
        )
    }
}
