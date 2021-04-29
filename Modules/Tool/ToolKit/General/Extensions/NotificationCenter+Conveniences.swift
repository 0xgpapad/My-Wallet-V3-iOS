// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Foundation

public extension NotificationCenter {
    @discardableResult static func when(_ name: NSNotification.Name, action: @escaping (Notification) -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: .main,
            using: action
        )
    }
}
