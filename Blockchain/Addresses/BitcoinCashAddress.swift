//
//  BitcoinCashAddress.swift
//  Blockchain
//
//  Created by Maurice A. on 4/26/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

// TODO: convert class to struct once there are no more objc dependents

@objc
public class BitcoinCashAddress: NSObject & AssetAddress {

    // MARK: - Properties

    public private(set) var address: String

    public var assetType: AssetType

    override public var description: String {
        return address
    }

    // MARK: - Initialization

    public required init(string: String) {
        self.address = string
        self.assetType = .bitcoinCash
    }
}
