//
//  QRCodeScannerDelegateMock.swift
//  TestKit
//
//  Created by Paulo on 25/02/2021.
//  Copyright © 2021 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import PlatformUIKit

final class QRCodeScannerDelegateMock: QRCodeScannerDelegate {
    var scanCompleteCalled: (Result<String, QRScannerError>) -> Void = { _ in }
    var scanCompleteResults: [Result<String, QRScannerError>] = []
    func scanComplete(with result: Result<String, QRScannerError>) {
        scanCompleteResults.append(result)
        scanCompleteCalled(result)
    }

    var didStartScanningCalled: () -> Void = { }
    var didStartScanningCallCount: Int = 0
    func didStartScanning() {
        didStartScanningCallCount += 1
        didStartScanningCalled()
    }

    var didStopScanningCalled: () -> Void = { }
    var didStopScanningCallCount: Int = 0
    func didStopScanning() {
        didStopScanningCallCount += 1
        didStopScanningCalled()
    }
}
