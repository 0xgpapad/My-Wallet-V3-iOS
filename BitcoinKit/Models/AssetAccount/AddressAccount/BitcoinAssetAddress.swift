//
//  BitcoinAddress.swift
//  BitcoinKit
//
//  Created by kevinwu on 2/5/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit

public struct BitcoinAssetAddress: AssetAddress, Importable, Hashable {
    public let isImported: Bool
    public let publicKey: String
    
    public init(isImported: Bool = false, publicKey: String) {
        self.isImported = isImported
        self.publicKey = publicKey
    }
}
