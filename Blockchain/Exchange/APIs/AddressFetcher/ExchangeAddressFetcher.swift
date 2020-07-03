//
//  ExchangeAddressFetcher.swift
//  Blockchain
//
//  Created by Daniel Huri on 22/07/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import NetworkKit
import PlatformKit
import RxSwift

/// Exchange address fetcher, should be used to fetch the address of the Exchange linked account
final class ExchangeAddressFetcher: ExchangeAddressFetching {
    
    // MARK: - Types
    
    enum FetchingError: Error {
        
        /// An error thrown when the user doesn't have an Exchange account to fetch his Exchange address from
        case missingAccount
        
        /// Two factor authentication required
        case twoFactorRequired
    }
    
    struct AddressResponseBody: Decodable {
        
        // MARK: - Types
        
        /// Error to be thrown in case decoding is unsuccessful
        enum ResponseError: Error {
            case assetType
            case state
            case address
            case inactiveState
        }
        
        /// State of Exchange account linking
        enum State: String {
            case pending = "PENDING"
            case active = "ACTIVE"
            case blocked = "BLOCKED"
            
            /// Returns `true` for an active state
            var isActive: Bool {
                switch self {
                case .active:
                    return true
                case .pending, .blocked:
                    return false
                }
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case state
            case currency
            case address
        }

        /// The asset type
        let assetType: CryptoCurrency
        
        /// The address associated with the asset type
        let address: String

        /// Thr state of the account
        let state: State
        
        // MARK: - Setup
        
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            address = try values.decode(String.self, forKey: .address)
            guard !address.isEmpty else {
                throw ResponseError.address
            }
            
            let currency = try values.decode(String.self, forKey: .currency)
            if let assetType = CryptoCurrency(code: currency) {
                self.assetType = assetType
            } else {
                throw ResponseError.assetType
            }
            let stateRawValue = try values.decode(String.self, forKey: .state)
            if let state = State(rawValue: stateRawValue) {
                if state.isActive {
                    self.state = state
                } else {
                    throw ResponseError.inactiveState
                }
                
            } else {
                throw ResponseError.state
            }
        }
    }
    
    private struct AddressRequestBody: Encodable {
        let currency: String
    }
    
    // MARK: - Properties
    
    private let featureConfigurator: FeatureConfiguring
    private let communicator: NetworkCommunicatorAPI
    private let repository: ExchangeAccountRepositoryAPI
    private let urlPrefix: String
        
    // MARK: - Setup
    
    init(featureConfigurator: FeatureConfiguring = AppFeatureConfigurator.shared,
         repository: ExchangeAccountRepositoryAPI = ExchangeAccountRepository(),
         communicator: NetworkCommunicatorAPI = Network.Dependencies.retail.communicator,
         urlPrefix: String = BlockchainAPI.shared.retailCoreUrl) {
        self.communicator = communicator
        self.repository = repository
        self.featureConfigurator = featureConfigurator
        self.urlPrefix = urlPrefix
    }

    // MARK: - Endpoint
    
    /// Fetches the Exchange address for a given asset type
    func fetchAddress(for asset: CryptoCurrency) -> Single<String> {
        
        /// Make sure that the config for Exchange is enabled before moving on to fetch the address
        guard featureConfigurator.configuration(for: .exchangeLinking).isEnabled else {
            return Single.error(AppFeatureConfiguration.ConfigError.disabled)
        }
        let url = "\(urlPrefix)/payments/accounts/linked"
        let data = AddressRequestBody(currency: asset.code)
        
        return repository.hasLinkedExchangeAccount
            .map { hasLinkedAccount -> Void in
                guard hasLinkedAccount else { throw FetchingError.missingAccount }
                return ()
            }
            .flatMap(weak: self) { (self, token) -> Single<AddressResponseBody> in
                self.communicator.perform(
                    request: NetworkRequest(
                        endpoint: URL(string: url)!,
                        method: .put,
                        body: try? JSONEncoder().encode(data),
                        authenticated: true
                    )
                )
            }
            // Catch two factor authentication errors and throw them, in case of other errors just rethrow
            .catchError { error in
                guard let networkError = error as? NetworkCommunicatorError else {
                    throw error
                }
                if case let .serverError(serverError) = networkError,
                        let nabuError = serverError.nabuError,
                        nabuError.code == .bad2fa {
                    throw FetchingError.twoFactorRequired
                } else {
                    throw networkError
                }
            }
            .map { $0.address }
    }
}
