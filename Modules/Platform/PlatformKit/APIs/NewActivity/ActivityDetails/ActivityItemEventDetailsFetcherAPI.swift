//
//  ActivityItemEventDetailsFetcherAPI.swift
//  PlatformKit
//
//  Created by Alex McGregor on 6/5/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxRelay
import RxSwift

public protocol ActivityItemEventDetailsFetcherAPI: AnyObject {
    associatedtype Model
    func details(for identifier: String) -> Observable<Model>
}
