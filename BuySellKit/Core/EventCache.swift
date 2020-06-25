//
//  EventCache.swift
//  Blockchain
//
//  Created by Daniel Huri on 11/02/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import ToolKit

public final class EventCache {
    
    // MARK: - Types
    
    public enum Key: String, CaseIterable {
        case hasShownIntroScreen = "simple-buy-intro-screen-shown"
        case hasShownBuyScreen = "simple-buy-buy-screen-shown"
    }
    
    // MARK: - Subscript
    
    /// Key subscript for an entry
    public subscript(key: Key) -> Bool {
        set {
            cacheSuite.set(newValue, forKey: key.rawValue)

        }
        get {
            cacheSuite.bool(forKey: key.rawValue)
        }
    }
        
    // MARK: - Private Properties
    
    private let cacheSuite: CacheSuite
    
    // MARK: - Setup
    
    init(cacheSuite: CacheSuite) {
        self.cacheSuite = cacheSuite
    }
    
    public func reset() {
        Key.allCases.forEach { cacheSuite.removeObject(forKey: $0.rawValue) }
    }
}