//
//  MockParser.swift
//  TransactionUIKitTests
//
//  Created by Paulo on 25/02/2021.
//  Copyright © 2021 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit

final class MockQRCodeScannerParser: QRCodeScannerParsing {

    enum MockParserError: Error {
        case unknown
    }

    struct Model: Equatable {
        let value: String
    }

    var underlyingParse: (Result<String, QRScannerError>) -> Result<Model, MockParserError> = { result in
        guard case .success(let scannedString) = result else {
            return .failure(.unknown)
        }
        return .success(Model(value: scannedString))
    }

    func parse(scanResult: Result<String, QRScannerError>, completion: ((Result<Model, MockParserError>) -> Void)?) {
        completion?(underlyingParse(scanResult))
    }
}
