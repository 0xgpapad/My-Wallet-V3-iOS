//
//  PinStoreResponse.swift
//  Blockchain
//
//  Created by Chris Arriola on 4/30/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

public struct PinStoreResponse: Decodable & Error {
    
    public enum StatusCode: Int, Decodable {
        case success = 0 // Pin retry succeeded
        case deleted = 1 // Pin retry failed and data was deleted from store
        case incorrect = 2 // Incorrect pin
    }
    
    private enum CodingKeys: String, CodingKey {
        case code = "code"
        case error = "error"
        case pinDecryptionValue = "success"
        case key = "key"
        case value = "value"
    }

    // This is a status code from the server
    public let statusCode: StatusCode?

    // This is an error string from the server or nil
    public let error: String?

    // The PIN decryption value from the server
    public let pinDecryptionValue: String?

    /// Pin code lookup key
    let key: String?

    /// Encryption string
    let value: String?
}

extension PinStoreResponse {
    
    /// Is the response successful
    public var isSuccessful: Bool {
        statusCode == .success && error == nil
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        statusCode = try values.decode(StatusCode.self, forKey: .code)
        pinDecryptionValue = try values.decodeIfPresent(String.self, forKey: .pinDecryptionValue)
        key = try values.decodeIfPresent(String.self, forKey: .key)
        value = try values.decodeIfPresent(String.self, forKey: .value)
        error = try values.decodeIfPresent(String.self, forKey: .error)
    }
}

