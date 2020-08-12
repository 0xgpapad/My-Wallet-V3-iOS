//
//  WalletIntroductionRecorder.swift
//  Blockchain
//
//  Created by AlexM on 8/29/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import PlatformKit
import ToolKit

/// A class that records actions taken by the user when interacting with a `WalletIntroductionEvent`.
/// We record the interaction so that it wouldn't be shown after the user interacts with the event.
/// This is how we resume the introduction from the last location that the user left off at.
final class WalletIntroductionRecorder {
    
    // MARK: - Properties
    
    private let cache: CacheSuite
    
    /// Key subscript for an entry
    subscript(key: String) -> Entry {
        Entry(recorder: self, key: key)
    }
    
    // MARK: - Setup
    
    init(cache: CacheSuite = resolve()) {
        self.cache = cache
    }
}

extension WalletIntroductionRecorder {
    
    final class Entry: Hashable, Equatable {
        
        // MARK: - Properties
        
        private unowned let recorder: WalletIntroductionRecorder
        
        /// The key to the cache suite
        private let key: String
        
        /// Keep in cache whether the `WalletIntroductionEvent` was interacted with.
        private(set) var value: WalletIntroductionLocation? {
            get {
                recorder.cache.object(forKey: key) as? WalletIntroductionLocation
            }
            set {
                if let newValue = newValue {
                    do {
                        let data = try JSONEncoder().encode(newValue)
                        recorder.cache.set(data, forKey: key)
                    } catch {
                        Logger.shared.error(error)
                    }
                } else {
                    recorder.cache.removeObject(forKey: key)
                }
            }
        }
        
        // MARK: - Setup
        
        init(recorder: WalletIntroductionRecorder, key: String = UserDefaults.Keys.walletIntroLatestLocation.rawValue) {
            self.recorder = recorder
            self.key = key
        }
        
        /// Updates the latest location in cache.
        
        func updateLatestLocation(_ location: WalletIntroductionLocation) {
            value = location
        }
        
        // MARK: Hashable
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }
        
        // MARK: - Equatable
        
        static func == (lhs: WalletIntroductionRecorder.Entry,
                        rhs: WalletIntroductionRecorder.Entry) -> Bool {
            lhs.key == rhs.key
        }
    }
}
