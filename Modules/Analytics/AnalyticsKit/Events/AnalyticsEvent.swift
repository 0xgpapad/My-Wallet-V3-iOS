//
//  AnalyticsEvent.swift
//  Blockchain
//
//  Created by Maciej Burda on 21/04/2021.
//  Copyright © 2021 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

public protocol AnalyticsEvent {
    var timestamp: Date? { get }
    var name: String { get }
    var params: [String: String]? { get }
    var type: AnalyticsEventType { get }
}

public extension AnalyticsEvent {
    var type: AnalyticsEventType {
        .old
    }
    
    var timestamp: Date? {
        nil
    }
    
    var params: [String: String]? {
        nil
    }
}
