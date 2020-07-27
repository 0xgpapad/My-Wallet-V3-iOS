//
//  DefaultWalletActionCellPresenter.swift
//  PlatformUIKit
//
//  Created by Alex McGregor on 7/21/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import Localization
import PlatformKit

public final class DefaultWalletActionCellPresenter {
    
    private typealias AccessibilityId = Accessibility.Identifier.WalletActionSheet
    private typealias LocalizationId = LocalizationConstants.WalletAction.Default
    
    let badgeImageViewModel: BadgeImageViewModel
    let titleLabelContent: LabelContent
    let descriptionLabelContent: LabelContent
    let action: WalletAction
    init(currencyType: CurrencyType, action: WalletAction) {
        self.action = action
        
        var templateColor: UIColor = .clear
        switch currencyType {
        case .crypto(let crypto):
            templateColor = crypto.brandColor
        case .fiat:
            templateColor = .fiat
        }
        self.badgeImageViewModel = .template(
            with: action.imageName,
            templateColor: templateColor,
            backgroundColor: templateColor.withAlphaComponent(0.15),
            accessibilityIdSuffix: "\(action.accessibilityId)"
        )
        
        titleLabelContent = .init(
            text: action.name,
            font: .main(.semibold, 16.0),
            color: .textFieldText,
            alignment: .left,
            accessibility: .id(AccessibilityId.Action.title)
        )
        
        var description: String = ""
        
        switch action {
        case .activity:
            description = LocalizationId.Activity.description
        case .deposit:
            description = .init(format: LocalizationId.Deposit.description, currencyType.symbol)
        case .transfer:
            description = .init(format: LocalizationId.Transfer.description, currencyType.symbol)
        case .withdraw:
            description = LocalizationId.Withdraw.description
        case .interest:
            description = .init(format: LocalizationId.Interest.description, currencyType.symbol)
        case .send:
            description = .init(format: LocalizationId.Send.description, currencyType.symbol)
        case .receive:
            description = .init(format: LocalizationId.Receive.description, currencyType.symbol)
        case .swap:
            description = .init(format: LocalizationId.Swap.description, currencyType.symbol)
        case .buy:
            description = LocalizationId.Buy.description
        case .sell:
            description = LocalizationId.Sell.description
        }
        
        descriptionLabelContent = .init(
            text: description,
            font: .main(.medium, 14.0),
            color: .descriptionText,
            alignment: .left,
            accessibility: .id(AccessibilityId.Action.description)
        )
    }
}
