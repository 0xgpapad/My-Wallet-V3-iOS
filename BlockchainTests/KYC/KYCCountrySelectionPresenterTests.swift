//
//  KYCCountrySelectionPresenterTests.swift
//  BlockchainTests
//
//  Created by Chris Arriola on 8/13/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import XCTest

@testable import Blockchain
@testable import PlatformKit

class KYCCountrySelectionPresenterTests: XCTestCase {

    private var view: MockKYCCountrySelectionView!
    private var walletService: MockWalletService!
    private var presenter: KYCCountrySelectionPresenter!

    override func setUp() {
        super.setUp()
        view = MockKYCCountrySelectionView()
        walletService = MockWalletService()
        presenter = KYCCountrySelectionPresenter(view: view)
    }

    func testSelectedSupportedKycCountry() {
        view.didCallContinueKycFlow = expectation(description: "Continue KYC flow when user selects valid KYC country.")
        let country = CountryData(code: "TEST", name: "Test Country", regions: [], scopes: ["KYC"], states: [])
        presenter.selected(country: country)
        waitForExpectations(timeout: 0.1)
    }

    func testSelectedCountryWithStates() {
        view.didCallContinueKycFlow = expectation(
            description: """
            KYC flow continues when user selects a country with states even if the country is not available for KYC
            """
        )
        let country = CountryData(code: "TEST", name: "Test Country", regions: [], scopes: [], states: ["CA"])
        presenter.selected(country: country)
        waitForExpectations(timeout: 0.1)
    }
}
