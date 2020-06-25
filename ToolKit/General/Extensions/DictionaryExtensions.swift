//
//  DictionaryExtensions.swift
//  PlatformKit
//
//  Created by Jack on 05/06/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

extension Dictionary {
    public func compactMapValues<T>(_ transform: (Value) throws -> T?) rethrows -> Dictionary<Key, T> {
        try self.reduce(into: [Key: T](), { (result, x) in
            if let value = try transform(x.value) {
                result[x.key] = value
            }
        })
    }
}

extension Dictionary {
    /// Merges two dictionary. duplicate keys would cause values to be overridden
    public mutating func append(with dictionary: Dictionary<Key, Value>) {
        for (key, value) in dictionary {
            self[key] = value
        }
    }
    /// Merges two dictionary. duplicate keys would cause values to be overridden
    public func merge(with dictionary: Dictionary<Key, Value>) -> Dictionary<Key, Value> {
        var mutableSelf = self
        for (key, value) in dictionary {
            mutableSelf[key] = value
        }
        return mutableSelf
    }
}

/// Convenience alternative to `append`
public func += <Key, Value> (lhs: inout Dictionary<Key, Value>,
                             rhs: Dictionary<Key, Value>) {
    lhs.append(with: rhs)
}

/// Convenience alternative to `merge`
public func + <Key, Value> (lhs: Dictionary<Key, Value>,
                            rhs: Dictionary<Key, Value>) -> Dictionary<Key, Value> {
    lhs.merge(with: rhs)
}

extension Dictionary where Key == String, Value == [String: Any] {
    /// Cast the `[String: [String: Any]]` objects in this Dictionary to instances of `Type`
    ///
    /// - Parameter type: the type
    /// - Returns: the casted array
    public func decodeJSONObjects<T: Codable>(type: T.Type) -> Dictionary<String, T> {
        let jsonDecoder = JSONDecoder()
        return compactMapValues { value -> T? in
            guard let data = try? JSONSerialization.data(withJSONObject: value, options: []) else {
                Logger.shared.warning("Failed to serialize dictionary.")
                return nil
            }
            
            do {
                return try jsonDecoder.decode(type.self, from: data)
            } catch {
                Logger.shared.error("Failed to decode \(error)")
            }
            
            return nil
        }
    }
    
    public func decodeJSONValues<T: Codable>(type: T.Type) -> [T] {
        decodeJSONObjects(type: type)
            .compactMap { (tuple) -> T? in
                let (_, value) = tuple
                return value
            }
    }
}

