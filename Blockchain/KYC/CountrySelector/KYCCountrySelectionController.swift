//
//  KYCCountrySelectionController.swift
//  Blockchain
//
//  Created by Maurice A. on 7/9/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import UIKit
import RxSwift
import ToolKit
import PlatformKit

typealias Countries = [CountryData]

/// Country selection screen in KYC flow
final class KYCCountrySelectionController: KYCBaseViewController, ProgressableView {

    // MARK: - ProgressableView

    @IBOutlet var progressView: UIProgressView!
    var barColor: UIColor = .green
    var startingValue: Float = 0.4

    // MARK: - IBOutlets

    @IBOutlet private var searchBar: UISearchBar!
    @IBOutlet private var tableView: UITableView!

    // MARK: - Private Properties

    private var countriesMap = SearchableMap<CountryData>()

    private lazy var presenter: KYCCountrySelectionPresenter = {
        return KYCCountrySelectionPresenter(view: self)
    }()
    
    private let analyticsRecorder: AnalyticsEventRecording = AnalyticsEventRecorder.shared
    private let informationService = UserInformationServiceProvider.default.general
    
    private let disposeBag = DisposeBag()

    // MARK: - Factory

    override class func make(with coordinator: KYCCoordinator) -> KYCCountrySelectionController {
        let controller = makeFromStoryboard()
        controller.coordinator = coordinator
        controller.pageType = .country
        return controller
    }

    // MARK: - View Controller Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupProgressView()
        tableView.dataSource = self
        tableView.delegate = self
        searchBar.delegate = self
        fetchListOfCountries()
    }

    // MARK: - Private Methods

    private func fetchListOfCountries() {
        informationService.countries
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] countries in
                self?.countriesMap.setAllItems(countries)
                self?.tableView.reloadData()
            })
            .disposed(by: disposeBag)
    }
}

extension KYCCountrySelectionController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        countriesMap.searchText = searchText
        tableView.reloadData()
    }
}

extension KYCCountrySelectionController: UITableViewDataSource, UITableViewDelegate {

    // MARK: UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let firstLetter = countriesMap.firstLetters[section]
        return countriesMap.items(firstLetter: firstLetter)?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let countryCell = tableView.dequeueReusableCell(withIdentifier: "CountryCell") else {
            return UITableViewCell()
        }

        guard let country = countriesMap.item(at: indexPath) else {
            return UITableViewCell()
        }

        countryCell.textLabel?.text = country.name

        return countryCell
    }

    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return index
    }

    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        guard countriesMap.searchText?.isEmpty ?? true else {
            return nil
        }
        return countriesMap.firstLetters
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return countriesMap.keys.count
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        searchBar.resignFirstResponder()
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let selectedCountry = countriesMap.item(at: indexPath) else {
            Logger.shared.warning("Could not infer selected country.")
            return
        }
        Logger.shared.info("User selected '\(selectedCountry.name)'")
        
        presenter.selected(country: selectedCountry)
        analyticsRecorder.record(event: AnalyticsEvents.KYC.kycCountrySelected)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension KYCCountrySelectionController: KYCCountrySelectionView {
    func continueKycFlow(country: CountryData) {
        let payload = KYCPagePayload.countrySelected(country: country)
        coordinator.handle(event: .nextPageFromPageType(pageType, payload))
    }
    func showExchangeNotAvailable(country: CountryData) {
        coordinator.handle(event: .failurePageForPageType(pageType, .countryNotSupported(country)))
    }
}
