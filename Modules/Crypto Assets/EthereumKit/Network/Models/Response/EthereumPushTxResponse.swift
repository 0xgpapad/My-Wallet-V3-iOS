//
//  EthereumPushTxResponse.swift
//  EthereumKit
//
//  Created by Jack on 19/09/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

public struct EthereumPushTxResponse: Decodable, Equatable {
    public let txHash: String
    
    public init(txHash: String) {
        self.txHash = txHash
    }
}
