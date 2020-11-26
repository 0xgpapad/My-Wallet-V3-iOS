//
//  Decimal+Extensions.swift
//  ToolKit
//
//  Created by Daniel on 14/07/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

extension Decimal {
    
    public var doubleValue: Double {
        (self as NSDecimalNumber).doubleValue
    }

    public func roundTo(places: Int, roundingMode: RoundingMode = .bankers) -> Decimal {
        let roundingBehaviour = NSDecimalNumberHandler(
            roundingMode: roundingMode,
            scale: Int16(places),
            raiseOnExactness: true,
            raiseOnOverflow: true,
            raiseOnUnderflow: true,
            raiseOnDivideByZero: true
        )
        let rounded = (self as NSDecimalNumber)
            .rounding(accordingToBehavior: roundingBehaviour)
        return rounded as Decimal
    }
}
