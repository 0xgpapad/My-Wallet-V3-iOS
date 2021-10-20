// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Foundation

struct Options: Equatable, Codable {
    let pbkdf2Iterations: Int
    let feePerKB: Int
    let html5Notifications: Bool
    let logoutTime: Int

    enum CodingKeys: String, CodingKey {
        case pbkdf2Iterations = "pbkdf2_iterations"
        case feePerKB = "fee_per_kb"
        case html5Notifications = "html5_notifications"
        case logoutTime = "logout_time"
    }
}
