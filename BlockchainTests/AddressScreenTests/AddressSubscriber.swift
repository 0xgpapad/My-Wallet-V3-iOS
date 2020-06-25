//
//  AddressSubscriber.swift
//  BlockchainTests
//
//  Created by Daniel Huri on 02/07/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

@testable import Blockchain
import PlatformKit

struct AddressSubscriberMock: AssetAddressSubscribing {
    func subscribe(to address: String, asset: CryptoCurrency, addressType: AssetAddressType) {}
}
