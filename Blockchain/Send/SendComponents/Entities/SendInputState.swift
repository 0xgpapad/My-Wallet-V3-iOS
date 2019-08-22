//
//  SendInputState.swift
//  Blockchain
//
//  Created by Daniel Huri on 13/08/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import PlatformUIKit
import EthereumKit

/// The state of the input
enum SendInputState {
    
    /// The state of the input is valid
    case valid
    
    /// Something is being calculated
    case calculating
    
    /// The input is currently empty
    case empty
    
    /// The input is invalid - see `StateError` for reason
    case invalid(StateError)
}

extension SendInputState {
    
    /// The error associated with an `.invalid` state of input
    enum StateError: Error {
        
        /// Balance doesn't have enough fee to cover the transaction
        case feeCoverage
        
        /// The destination address is not valid
        case destinationAddress
        
        /// There is a transaction in progress
        case pendingTransaction
        
        case `default`
        
        init(error: Error) {
            switch error {
            case EthereumKitValidationError.waitingOnPendingTransaction:
                self = .pendingTransaction
            case EthereumKitValidationError.insufficientFeeCoverage, EthereumKitValidationError.insufficientFunds:
                self = .feeCoverage
            case EthereumWalletServiceError.unknown:
                self = .default
            default:
                self = .default
            }
        }
    }
    
    init(error: Error) {
        self = .invalid(StateError(error: error))
    }
    
    init(amountCalculationState: SendCalculationState,
         feeCalculationState: SendCalculationState,
         destinationAccountState: SendDestinationAccountState,
         amountBalanceRatio: AmountBalanceRatio) {
        switch (amountCalculationState, feeCalculationState, destinationAccountState, amountBalanceRatio) {
        // All values are valid
        case (.value, .value, .valid, .withinSpendableBalance):
            self = .valid
        // The destination address is not in the proper format
        case (_, _, .invalid(.format), _):
            self = .invalid(.destinationAddress)
        // Fee coverage is not enough
        case (_, _, _, .aboveSpendableBalance):
            self = .invalid(.feeCoverage)
        // Calculating state
        case (.calculating, _, _, _),
             (_, .calculating, _, _):
            self = .calculating
        // Empty state (missing input such as destination address, amount, fee)
        case (.invalid(.empty), _, _, _),
             (_, .invalid(.empty), _, _),
             (_, _, .invalid(.empty), _):
            self = .empty
        default:
            self = .invalid(.default)
        }
    }
    
    /// Retruns `true` for a valid state
    var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .calculating, .empty, .invalid:
            return false
        }
    }
}

extension SendInputState.StateError {
    
    private typealias LocalizedString = LocalizationConstants.Send.Error
    
    /// Returns title for the error
    func title(for asset: AssetType) -> String {
        switch asset {
        case .ethereum:
            switch self {
            case .feeCoverage:
                return String(format: LocalizedString.Balance.title, asset.symbol)
            case .destinationAddress:
                return String(format: LocalizedString.DestinationAddress.title, asset.symbol)
            case .pendingTransaction:
                return LocalizedString.PendingTransaction.title
            case .default: // Should not reach here
                return LocalizationConstants.Errors.error
            }
        case .bitcoin, .bitcoinCash, .pax, .stellar:
            fatalError("\(#function) does not support \(asset.description) yet")
        }
    }
    
    /// Returns description for the error
    func description(for asset: AssetType) -> String? {
        switch asset {
        case .ethereum:
            switch self {
            case .feeCoverage:
                return String(format: LocalizedString.Balance.description, asset.symbol)
            case .destinationAddress:
                return String(format: LocalizedString.DestinationAddress.description, asset.symbol)
            case .pendingTransaction:
                return String(format: LocalizedString.PendingTransaction.title, asset.symbol)
            case .default: // Should not reach here
                return nil
            }
        case .bitcoin, .bitcoinCash, .pax, .stellar:
            fatalError("\(#function) does not support \(asset.description) yet")
        }
    }
}
