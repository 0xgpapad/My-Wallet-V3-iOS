//
//  AlgorandDependencies.swift
//  Blockchain
//
//  Created by Paulo on 09/06/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit

public protocol AlgorandDependencies {
    var activity: ActivityItemEventServiceAPI { get }
}
