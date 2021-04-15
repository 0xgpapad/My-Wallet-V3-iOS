//
//  AnnouncementRecord+Category.swift
//  PlatformUIKit
//
//  Created by Daniel Huri on 23/08/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

extension AnnouncementRecord {
    
    /// The category of the announcement
    public enum Category: String, Codable {
        case persistent
        case periodic
        case oneTime
    }
}
