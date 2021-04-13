//
//  CheckoutInteractionData.swift
//  PlatformKit
//
//  Created by Daniel Huri on 02/06/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit

public struct CheckoutInteractionData {
    public let time: Date?
    public let fee: MoneyValue
    public let amount: MoneyValue
    public let exchangeRate: MoneyValue?
    public let card: CardData?
    public let bankTransferData: LinkedBankData?
    public let orderId: String
    public let paymentMethod: PaymentMethod.MethodType
    
    public init(time: Date?,
                fee: MoneyValue,
                amount: MoneyValue,
                exchangeRate: MoneyValue?,
                card: CardData?,
                bankTransferData: LinkedBankData?,
                orderId: String,
                paymentMethod: PaymentMethod.MethodType) {
        self.time = time
        self.fee = fee
        self.amount = amount
        self.exchangeRate = exchangeRate
        self.card = card
        self.bankTransferData = bankTransferData
        self.orderId = orderId
        self.paymentMethod = paymentMethod
    }
}
