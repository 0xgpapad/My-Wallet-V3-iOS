//
//  Data+Extensions.swift
//  CommonCryptoKit
//
//  Created by Jack on 19/08/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

extension Data {
    
    public var hexValue: String {
        return map { String(format: "%02x", $0) }.reduce("", +)
    }
    
    public init(hex: String) {
        let len = hex.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hex.index(hex.startIndex, offsetBy: i*2)
            let k = hex.index(j, offsetBy: 2)
            let bytes = hex[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                self = Data()
                return
            }
        }
        self = data
    }
    
}
