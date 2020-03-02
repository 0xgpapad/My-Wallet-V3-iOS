//
//  KYCTierState.swift
//  Blockchain
//
//  Created by kevinwu on 12/12/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

extension KYC.Tier {
    public enum State: String, Codable {
        case none
        case rejected
        case pending
        case verified
    }
}
