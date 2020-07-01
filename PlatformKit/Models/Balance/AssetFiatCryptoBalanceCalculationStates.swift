//
//  FiatCryptoPairCalculationStates.swift
//  Blockchain
//
//  Created by Daniel Huri on 31/10/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

/// This construct provides access to aggregated fiat-crypto-pair calculation states.
/// Any supported asset balance should be accessible here.
public struct AssetFiatCryptoBalanceCalculationStates {
    
    // MARK: - Properties
        
    /// Returns `FiatCryptoPairCalculationState` for a given `CryptoCurrency`
    public subscript(cyptoCurrency: CryptoCurrency) -> AssetFiatCryptoBalanceCalculationState {
        statePerCurrency[cyptoCurrency]!
    }
    
    /// Returns all the states
    public var all: [AssetFiatCryptoBalanceCalculationState] {
        Array(statePerCurrency.values)
    }
    
    /// All elements must be `.calculating` for that to return `true`
    public var isCalculating: Bool {
        !all.contains { !$0.isCalculating }
    }
    
    /// Must contain an `.invalid` element for that to return `true`
    public var isInvalid: Bool {
        all.contains { $0.isInvalid }
    }
    
    /// All elements must have a value for that to return `true`
    public var isValue: Bool {
        !all.contains { !$0.isValue }
    }
    
    /// Some elements must have a value for that to return `true`
    public var containsValue: Bool {
        all.contains { $0.isValue }
    }
    
    /// Returns the total fiat calcuation state
    public var totalFiat: FiatValueCalculationState {
        guard !isInvalid else {
            return .invalid(.valueCouldNotBeCalculated)
        }
        guard !isCalculating else {
            return .calculating
        }
        do {
            let values = all.compactMap { $0.value?.fiat }
            let total = try values.dropFirst().reduce(values[0], +)
            return .value(total)
        } catch {
            return .invalid(.valueCouldNotBeCalculated)
        }
    }
    
    // MARK: - Private Properties
    
    private var statePerCurrency: [CryptoCurrency: AssetFiatCryptoBalanceCalculationState] = [:]
    
    // MARK: - Setup
    
    public init(statePerCurrency: [CryptoCurrency: AssetFiatCryptoBalanceCalculationState]) {
        self.statePerCurrency = statePerCurrency
    }
}
