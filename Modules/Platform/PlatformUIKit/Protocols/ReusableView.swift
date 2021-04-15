//
//  ReusableView.swift
//  PlatformUIKit
//
//  Created by Alex McGregor on 7/26/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import UIKit

/// `ReusableView` makes working with reuse identifiers
/// simpler and more consistant in how they are derived.
public protocol ReusableView {
    static var identifier: String { get }
}

/// Implementation of the ReusableView protocol for
/// `UITableViewCell`
@objc extension UITableViewCell: ReusableView {
    public static var identifier: String { String(describing: self) }
}

/// Implementation of the ReusableView protocol for
/// `UICollectionViewCell`
extension UICollectionViewCell: ReusableView {
    public static var identifier: String { String(describing: self) }
}
