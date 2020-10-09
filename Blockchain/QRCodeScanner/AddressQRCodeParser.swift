//
//  AddressQRCodeParser.swift
//  Blockchain
//
//  Created by Jack on 18/02/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import PlatformKit
import ToolKit

final class AddressQRCodeParser: QRCodeScannerParsing {
    
    enum AddressQRCodeParserError: Error {
        case scanError(QRScannerError)
        case unableToCreatePayload
    }
    
    struct Address {
        let payload: CryptoAssetQRMetadata
    }
    
    private let assetType: CryptoCurrency
    
    init(assetType: CryptoCurrency) {
        self.assetType = assetType
    }
    
    func parse(scanResult: Result<String, QRScannerError>, completion: ((Result<Address, AddressQRCodeParserError>) -> Void)?) {
        switch scanResult {
        case .success(let address):
            handleSuccess(address: address, completion: completion)
        case .failure(let error):
            completion?(.failure(.scanError(error)))
        }
    }
    
    private func handleSuccess(address: String, completion: ((Result<Address, AddressQRCodeParserError>) -> Void)?) {
        guard let payload = AssetURLPayloadFactory.create(fromString: address, asset: assetType) else {
            Logger.shared.error("Could not create payload from scanned string: \(address)")
            completion?(.failure(.unableToCreatePayload))
            return
        }
        completion?(.success(Address(payload: payload)))
    }
}
