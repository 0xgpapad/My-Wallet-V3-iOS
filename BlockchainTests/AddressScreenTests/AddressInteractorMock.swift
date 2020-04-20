//
//  AddressInteractorMock.swift
//  BlockchainTests
//
//  Created by Daniel Huri on 02/07/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift

import PlatformKit
@testable import Blockchain

class AddressInteractorMock: AddressInteracting {
    
    let asset: CryptoCurrency
    let address: Single<WalletAddressContent>
    let receivedPayment: Observable<ReceivedPaymentDetails>
    
    init(asset: CryptoCurrency,
         address: WalletAddressContent,
         receivedPayment: ReceivedPaymentDetails) {
        self.asset = asset
        self.address = .just(address)
        self.receivedPayment = .just(receivedPayment)
    }
}
