//
//  BlockstackAccountRepositoryMock.swift
//  BlockchainTests
//
//  Created by Jack on 29/10/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import BitcoinKit
import Foundation
import RxSwift

class BlockstackAccountRepositoryMock: BlockstackAccountAPI {
    
    var accountAddressValue: Single<BlockstackAddress> = Single.just(BlockstackAddress(rawValue: "1EpGdGDjLgxVWU925a81R2aApsKgvFKPXD")!)
    var accountAddress: Single<BlockstackAddress> {
        accountAddressValue
    }
    
}
