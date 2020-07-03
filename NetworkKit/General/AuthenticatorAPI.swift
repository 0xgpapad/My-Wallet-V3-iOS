//
//  AuthenticatorAPI.swift
//  NetworkKit
//
//  Created by Jack Pooley on 29/06/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift

public protocol AuthenticatorAPI: AnyObject {
    
    @available(*, deprecated, message: "This is deprecated. Don't use this.")
    var token: Single<String> { get }
    
    /// Fetches authentication token
    /// - Parameter singleFunction: method requiring authentication token
    func authenticate<Response>(_ singleFunction: @escaping (String) -> Single<Response>) -> Single<Response>
    
    /// Fetches authentication token
    /// - Parameter singleFunction: method requiring authentication token
    ///
    /// *Note*: this method never throws!
    @available(*, deprecated, message: "Don't use this.")
    func authenticateWithResult<ResponseType: Decodable, ErrorResponseType: Error & Decodable>(
        _ singleFunction: @escaping (String) -> Single<Result<ResponseType, ErrorResponseType>>
    ) -> Single<Result<ResponseType, ErrorResponseType>>
}

public protocol Authenticatable: AnyObject {
    func use(authenticator: AuthenticatorAPI)
}
