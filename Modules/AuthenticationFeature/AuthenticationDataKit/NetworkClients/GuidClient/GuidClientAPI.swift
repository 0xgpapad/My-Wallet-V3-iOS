// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import NetworkKit
import RxSwift

public protocol GuidClientCombineAPI: AnyObject {
    /// An `AnyPublisher` that streams the `GUID` on success or fails due
    /// to network error.
    func guidPublisher(by sessionToken: String) -> AnyPublisher<String, NetworkError>
}

/// A `GUID` client/service API. A concrete type is expected to fetch the `GUID`
public protocol GuidClientAPI: GuidClientCombineAPI {
    /// A `Single` that streams the `GUID` on success or fails due
    /// to network error.
    func guid(by sessionToken: String) -> Single<String>
}
