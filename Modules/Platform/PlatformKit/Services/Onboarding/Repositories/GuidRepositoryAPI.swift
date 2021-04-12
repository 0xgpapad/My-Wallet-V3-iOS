//
//  GuidRepositoryAPI.swift
//  Blockchain
//
//  Created by Daniel Huri on 14/11/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift

public protocol GuidRepositoryAPI: class {
    
    /// Streams `Bool` indicating whether the guid is currently cached in the repo
    var hasGuid: Single<Bool> { get }
    
    /// Streams the cached guid or `nil` if it is not cached
    var guid: Single<String?> { get }
    
    /// Sets the guid
    func set(guid: String) -> Completable
}

public extension GuidRepositoryAPI {
    var hasGuid: Single<Bool> {
        guid.map { $0?.isEmpty == false }
    }
}
