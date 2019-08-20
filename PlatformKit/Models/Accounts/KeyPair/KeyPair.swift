//
//  KeyPair.swift
//  PlatformKit
//
//  Created by Alex McGregor on 11/12/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

public protocol KeyPair {
    associatedtype PrivateKey
    
    var privateKey: PrivateKey { get }
}
