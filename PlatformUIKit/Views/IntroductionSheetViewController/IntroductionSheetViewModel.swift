//
//  IntroductionSheetViewModel.swift
//  PlatformUIKit
//
//  Created by AlexM on 8/30/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

public struct IntroductionSheetViewModel {
    let title: String
    let description: String
    let thumbnail: UIImage
    let onSelection: () -> Void
    
    public init(title: String, description: String, thumbnail: UIImage, onSelection: @escaping () -> Void) {
        self.title = title
        self.description = description
        self.thumbnail = thumbnail
        self.onSelection = onSelection
    }
}
