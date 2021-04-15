//
//  Accessibility+AmountLabelView.swift
//  PlatformUIKit
//
//  Created by Daniel Huri on 28/01/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

extension Accessibility.Identifier {
    enum AmountLabelView {
        private static let prefix = "AmountLabelView."
        static let fiatCurrencyCodeLabel = "\(prefix)currencyCodeLabel.fiat"
        static let cryptoCurrencyCodeLabel = "\(prefix)currencyCodeLabel.crypto"
        static let amountLabel = "\(prefix)amountLabel.%@"
    }
}
