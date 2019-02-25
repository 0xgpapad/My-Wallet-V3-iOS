//
//  EthereumAssetAddress.swift
//  EthereumKit
//
//  Created by kevinwu on 2/6/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit

public struct EthereumAssetAddress: AssetAddress {
    public let isImported: Bool
    public let publicKey: String
}

