//
//  CardDeletionService.swift
//  PlatformKit
//
//  Created by Alex McGregor on 4/9/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import ToolKit
import PlatformKit

public protocol CardDeletionServiceAPI: class {
    /// Deletes a card with a given identifier
    func deleteCard(by id: String) -> Completable
}

public final class CardDeletionService: CardDeletionServiceAPI {
    
    // MARK: - Private Properties
    
    private let client: CardDeletionClientAPI
    private let authenticationService: NabuAuthenticationServiceAPI
    
    // MARK: - Setup
    
    public init(client: CardDeletionClientAPI,
                authenticationService: NabuAuthenticationServiceAPI) {
        self.authenticationService = authenticationService
        self.client = client
    }
    
    public func deleteCard(by id: String) -> Completable {
        authenticationService
            .tokenString
            .flatMapCompletable(weak: self) { (self, token) -> Completable in
                self.client.deleteCard(by: id, token: token)
            }
    }
    
}
