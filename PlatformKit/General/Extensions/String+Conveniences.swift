//
//  String+Conveniences.swift
//  PlatformKit
//
//  Created by Alex McGregor on 12/7/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

public extension String {
    
    /// Returns query arguments from a string in URL format
    var queryArgs: [String: String] {
        var queryArgs = [String: String]()
        let components = self.components(separatedBy: "&")
        components.forEach {
            let paramValueArray = $0.components(separatedBy: "=")
            
            if paramValueArray.count == 2,
                let param = paramValueArray[0].removingPercentEncoding,
                let value = paramValueArray[1].removingPercentEncoding {
                queryArgs[param] = value
            }
        }
        
        return queryArgs
    }
    
    /// Removes last char safely
    mutating func removeLastSafely() {
        guard !isEmpty else { return }
        removeLast()
    }
    
    /// Removes prefix
    mutating func remove(prefix: String) {
        guard hasPrefix(prefix) else { return }
        self = String(suffix(count - prefix.count))
    }
    
    func stringByRemoving(prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        var this = self
        this.remove(prefix: prefix)
        return this
    }
    
    /// Returns the string with no whitespaces
    public var trimmingWhitespaces: String {
        return trimmingCharacters(in: .whitespaces)
    }
}

extension String {
    public var isAlphanumeric: Bool {
        guard !isEmpty else {
            return false
        }
        guard rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil else {
            return false
        }
        return true
    }
}
