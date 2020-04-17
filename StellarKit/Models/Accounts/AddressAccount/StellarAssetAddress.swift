//
//  StellarAssetAddress.swift
//  StellarKit
//
//  Created by AlexM on 11/29/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit

public struct StellarAssetAddress: AssetAddress {
    public var publicKey: String
    
    public init(publicKey: String) {
        self.publicKey = publicKey
    }
}
