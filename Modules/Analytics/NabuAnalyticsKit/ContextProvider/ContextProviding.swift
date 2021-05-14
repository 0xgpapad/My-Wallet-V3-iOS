// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Foundation

protocol ContextProviding {
    var context: Context { get }
    var anonymousId: String { get }
}
