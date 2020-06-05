//
//  StellarWalletAccountRepositoryMock.swift
//  Blockchain
//
//  Created by Jack on 03/07/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import RxSwift
import PlatformKit
import StellarKit

class StellarWalletAccountRepositoryMock: StellarWalletAccountRepositoryAPI {
    func initializeMetadataMaybe() -> Maybe<StellarWalletAccount> {
        return Maybe.empty()
    }

    var defaultAccount: StellarWalletAccount?

    func loadKeyPair() -> Maybe<StellarKeyPair> {
        return Maybe.empty()
    }
}
