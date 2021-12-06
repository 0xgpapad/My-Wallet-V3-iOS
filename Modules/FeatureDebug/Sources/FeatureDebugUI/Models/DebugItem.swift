// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Foundation

enum DebugItemType: CaseIterable {
    case interalFeatureFlags
    case componentLibraryExamples
    case colorScheme
    case pulse
}

extension DebugItemType {
    var title: String {
        switch self {
        case .interalFeatureFlags:
            return "Internal Feature Flags"
        case .componentLibraryExamples:
            return "Component Library Examples"
        case .colorScheme:
            return "Switch Color Scheme (Light/Dark)"
        case .pulse:
            return "Network Debug Console"
        }
    }

    static func provideAllItems() -> [DebugItem] {
        DebugItemType.allCases.map(DebugItem.init(type:))
    }
}

struct DebugItem: Equatable {
    let title: String
    let type: DebugItemType

    init(type: DebugItemType) {
        title = type.title
        self.type = type
    }
}
