//
//  UIColor+Application.swift
//  PlatformUIKit
//
//  Created by Daniel Huri on 18/07/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

// MARK: - Color Palette - App Layer

/// Typealias to use instead of `UIColor`, to avoid from being dependent on `UIKit`
public typealias Color = UIColor

public extension UIColor {
    
    // Primary
    
    static let primary = blue900
    static let secondary = blue600
    static let tertiary = blue400

    // Navigation
    
    static let navigationBarBackground = blue900
    
    // Backgrounds & Borders
    
    static let background = grey000
    static let mediumBackground = grey100
    static let hightlightedBackground = grey50
    
    static let lightBorder = grey000
    static let mediumBorder = grey100
    static let destructiveBackground = red100
    static let affirmativeBackground = green100
    static let defaultBadgeBackground = blue100

    static let lightShimmering = grey000
    static let darkShimmering = grey200

    // Indications
    
    static let securePinGrey = greyFade400
    static let addressPageIndicator = blue100

    // MARK: Texts
    
    static let defaultBadge = blue600
    static let affirmativeBadgeText = green600
    
    static let normalPassword = green600
    static let strongPassword = blue600
    static let destructive = red600
    
    static let textFieldPlaceholder = grey400
    static let textFieldText = grey800
    static let titleText = grey800
    static let descriptionText = grey600
    static let mutedText = grey400
    
    static let dashboardAssetTitle = grey800
    static let dashboardFiatPriceTitle = grey800
    
    static let negativePrice = red400
    static let positivePrice = green500

    // Buttons
    
    static let airdropCTAButton = green600
    
    static let destructiveButton = red600
    static let successButton = green600
    static let primaryButton = blue600
    static let secondaryButton = grey800
    static let tertiaryButton = grey900
    static let linkableText = blue600
    
    static let iconDefault = grey400
    static let iconSelected = grey400
    static let iconWarning = orange600
    
    // Crypto
    
    static let bitcoin = btc
    static let ethereum = eth
    static let bitcoinCash = bch
    static let stellar = xlm
    static let paxos = pax
    
    // Tiers
    
    static let silverTier = tiersSilver
    static let goldTier = tiersGold
    static let diamondTier = tiersDiamond
    
    // MARK: - Feature Themes
    
    static let exchangeAnnouncementButton = grey800
    static let exchangeTheme = exchangeBackground
    static let blockastackCardBackground = blockstackBackground
}
