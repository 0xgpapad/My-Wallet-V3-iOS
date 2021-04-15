//
//  OrderPair.swift
//  TransactionKit
//
//  Created by Alex McGregor on 10/13/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import ToolKit

public struct OrderPair: RawRepresentable {
    
    public typealias RawValue = String
    
    enum OrderPairDecodingError: Error {
        case decodingError
    }
    
    public let sourceCurrencyType: CurrencyType
    public let destinationCurrencyType: CurrencyType
    
    public var rawValue: String {
        "\(sourceCurrencyType.code)-\(destinationCurrencyType.code)"
    }
    
    init(sourceCurrencyType: CurrencyType, destinationCurrencyType: CurrencyType) {
        self.sourceCurrencyType = sourceCurrencyType
        self.destinationCurrencyType = destinationCurrencyType
    }
    
    public init?(rawValue: String) {
        var components: [String] = []
        for value in ["-", "_"] {
            if rawValue.contains(value) {
                components = rawValue.components(separatedBy: value)
                break
            }
        }
        guard let source = components.first else { return nil }
        guard let destination = components.last else { return nil }
        do {
            let sourceType = try CurrencyType(code: source)
            let destionationType = try CurrencyType(code: destination)
            self.init(
                sourceCurrencyType: sourceType,
                destinationCurrencyType: destionationType
            )
        } catch {
            return nil
        }
    }
    
    init(string: String) throws {
        var components: [String] = []
        for value in ["-", "_"] {
            if string.contains(value) {
                components = string.components(separatedBy: value)
                break
            }
        }
        
        guard let source = components.first else {
            throw OrderPairDecodingError.decodingError
        }
        guard let destination = components.last else {
            throw OrderPairDecodingError.decodingError
        }
        let sourceType = try CurrencyType(code: source)
        let destionationType = try CurrencyType(code: destination)
        
        self.init(
            sourceCurrencyType: sourceType,
            destinationCurrencyType: destionationType
        )
    }
}
