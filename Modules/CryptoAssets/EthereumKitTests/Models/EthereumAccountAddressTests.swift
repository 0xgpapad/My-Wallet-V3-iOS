// Copyright © Blockchain Luxembourg S.A. All rights reserved.

@testable import EthereumKit
import XCTest

class EthereumAccountAddressTests: XCTestCase {
    
    func test_address_validation_fails_for_truncated_address() {
        var address = MockEthereumWalletTestData.account
        address.removeLast()

        XCTAssertNil(EthereumAccountAddress(rawValue: address))

        XCTAssertThrowsError(try EthereumAccountAddress(string: address)) { (error) in
            XCTAssertEqual(error as? AddressValidationError, .invalidLength)
        }
    }

    func test_address_validation_fails_for_invalid_characters_in_address() {
        // Sanity check
        XCTAssertTrue(MockEthereumWalletTestData.account.contains("e"))
        let invalidAddresses = ["😈", "&", "^", "󌞑"].map { invalidComponent -> String in
            MockEthereumWalletTestData.account.replacingOccurrences(of: "e", with: invalidComponent)
        }

        for address in invalidAddresses {
            XCTAssertNil(EthereumAccountAddress(rawValue: address))
            XCTAssertThrowsError(try EthereumAccountAddress(string: address)) { (error) in
                XCTAssertEqual(error as? AddressValidationError, .containsInvalidCharacters)
            }
        }
    }

    func test_address_validation_fails_for_invalid_length() {
        // Sanity check
        XCTAssertTrue(MockEthereumWalletTestData.account.contains("e"))
        let invalidAddresses = ["𝚨", "ee"].map { invalidComponent -> String in
            MockEthereumWalletTestData.account.replacingOccurrences(of: "e", with: invalidComponent)
        }

        for address in invalidAddresses {
            XCTAssertNil(EthereumAccountAddress(rawValue: address))
            XCTAssertThrowsError(try EthereumAccountAddress(string: address)) { (error) in
                XCTAssertEqual(error as? AddressValidationError, .invalidLength)
            }
        }
    }
}
