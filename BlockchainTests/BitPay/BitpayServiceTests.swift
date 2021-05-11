// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Foundation
import PlatformKit
import RxSwift
import XCTest

@testable import Blockchain

class BitpayServicesTests: XCTestCase {
    
    func testBitPayServiceGetRawPaymentRequest() {
        let invoiceId = "4vzRL5oK5EuJ31cqLmkLp5"
        let mock = MockBitpayService()
        do {
            let requestResponse: ObjcCompatibleBitpayObject = try mock.bitpayPaymentRequest(invoiceID: invoiceId,
                                          currency: .bitcoin).toBlocking().first()!
            XCTAssert(requestResponse.paymentUrl == ("https://bitpay.com/i/" + "\(invoiceId)"))
            XCTAssert(requestResponse.memo.contains(invoiceId))
        } catch {
            XCTFail("expected success, got \(error) instead")
        }
    }
    
}
