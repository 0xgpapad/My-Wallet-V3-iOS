//
//  AccountPickerHeaderModel.swift
//  PlatformUIKit
//
//  Created by Paulo on 28/08/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import Localization

public struct AccountPickerHeaderModel {
    public typealias LocalizedString = LocalizationConstants.WalletPicker
    static let defaultHeight: CGFloat = 169

    private let title: String
    private let subtitle: String
    let image: UIImage
    private let selectWallet: String

    var titleLabel: LabelContent {
        .init(
            text: title,
            font: .main(.semibold, 20),
            color: .titleText
        )
    }

    var subtitleLabel: LabelContent {
        .init(
            text: subtitle,
            font: .main(.medium, 14),
            color: .descriptionText
        )
    }

    var selectWalletLabel: LabelContent {
        .init(
            text: selectWallet,
            font: .main(.semibold, 12),
            color: .titleText
        )
    }

    public init(title: String,
                subtitle: String,
                image: UIImage,
                selectWallet: String = LocalizedString.selectAWallet) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.selectWallet = selectWallet
    }
}
