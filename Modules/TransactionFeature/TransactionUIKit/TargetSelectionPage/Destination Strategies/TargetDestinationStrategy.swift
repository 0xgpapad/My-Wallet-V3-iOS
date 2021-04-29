// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Localization
import PlatformKit
import ToolKit

/// Types adopting the `TargetDestinationsStrategyAPI` should provide a way to output an array of `TargetSelectionPageSectionModel` items
protocol TargetDestinationsStrategyAPI {
    func sections(interactors: [TargetSelectionPageCellItem.Interactor],
                  action: AssetAction) -> [TargetSelectionPageSectionModel]
}

// MARK: - Main Concrete Class

/// A container class adopting the `TargetDestinationsStrategyAPI`
/// which holds a concrete class of type `TargetDestinationsStrategyAPI` which provides a set of sections.
struct TargetDestinationSections: TargetDestinationsStrategyAPI {

    private let strategy: TargetDestinationsStrategyAPI

    init(strategy: TargetDestinationsStrategyAPI) {
        self.strategy = strategy
    }

    func sections(interactors: [TargetSelectionPageCellItem.Interactor],
                  action: AssetAction) -> [TargetSelectionPageSectionModel] {
        strategy.sections(interactors: interactors, action: action)
    }
}

// MARK: - Target Destination Section Enum

private enum TargetDestinationTitle {
    case to
    case orSelect
    case receive

    var text: String {
        switch self {
        case .to:
            return LocalizationConstants.Transaction.to
        case .orSelect:
            return LocalizationConstants.Transaction.orSelectAWallet
        case .receive:
            return LocalizationConstants.Transaction.receive
        }
    }
}

// MARK: - Trading Source DestinationStrategy

struct TradingSourceDestinationStrategy: TargetDestinationsStrategyAPI {

    private typealias LocalizationIds = LocalizationConstants.Transaction.TargetSource

    private let sourceAccount: SingleAccount

    init(sourceAccount: SingleAccount) {
        self.sourceAccount = sourceAccount
    }

    func sections(interactors: [TargetSelectionPageCellItem.Interactor],
                  action: AssetAction) -> [TargetSelectionPageSectionModel] {
        guard action == .send else {
            fatalError("given action: \(action) is not supported")
        }
        let items = interactors.map { interactor in
            TargetSelectionPageCellItem(interactor: interactor, assetAction: action)
        }
        let currency = sourceAccount.currencyType.name
        let code = sourceAccount.currencyType.displayCode
        let title = LocalizationIds.Card.internalSendOnly
        let description = String(
            format: LocalizationIds.Card.description, currency, code, code, currency
        )
        let cardItem = TargetSelectionPageCellItem(
            cardView: .transactionViewModel(
                with: title,
                description: description
            )
        )
        return [.destination(header: provideSectionHeader(action: action, title: .to), items: [cardItem] + items)]
    }
}

// MARK: - Non Trading Source DestinationStrategy

struct NonTradingSourceDestinationStrategy: TargetDestinationsStrategyAPI {

    private let sourceAccount: SingleAccount

    init(sourceAccount: SingleAccount) {
        self.sourceAccount = sourceAccount
    }

    func sections(interactors: [TargetSelectionPageCellItem.Interactor],
                  action: AssetAction) -> [TargetSelectionPageSectionModel] {
        guard action == .send else {
            fatalError("given action: \(action) is not supported")
        }

        let additionalWallets = interactors.compactMap { interactor -> TargetSelectionPageCellItem? in
            if !interactor.isWalletInputField {
                return TargetSelectionPageCellItem(interactor: interactor, assetAction: action)
            }
            return nil
        }

        var sections: [TargetSelectionPageSectionModel] = []
        if !additionalWallets.isEmpty {
            sections.append(
                .destination(header: provideSectionHeader(action: action, title: .orSelect), items: additionalWallets)
            )
        }
        return sections
    }
}

// MARK: - Section Header Provider method

private func provideSectionHeader(action: AssetAction, title: TargetDestinationTitle) -> TargetSelectionHeaderBuilder {
    switch action {
    case .swap:
        return TargetSelectionHeaderBuilder(
            headerType: .section(
                .init(
                    sectionTitle: title.text
                )
            )
        )
    case .send:
        return TargetSelectionHeaderBuilder(
            headerType: .section(
                .init(
                    sectionTitle: title.text
                )
            )
        )
    case .deposit,
         .receive,
         .sell,
         .viewActivity,
         .withdraw:
        unimplemented()
    }
}
