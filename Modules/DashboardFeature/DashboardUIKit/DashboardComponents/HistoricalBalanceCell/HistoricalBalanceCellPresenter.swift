// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import PlatformKit
import PlatformUIKit
import RxCocoa
import RxRelay
import RxSwift

final class HistoricalBalanceCellPresenter {
    
    private typealias AccessibilityId = Accessibility.Identifier.Dashboard.AssetCell
    
    var thumbnail: Driver<ImageViewContent> {
        .just(
            .init(
                imageName: interactor.cryptoCurrency.logoImageName,
                accessibility: .id("\(AccessibilityId.assetImageView)\(interactor.cryptoCurrency.displayCode)"),
                bundle: Bundle(for: Self.self)
            )
        )
    }
    
    var name: Driver<LabelContent> {
        .just(
            .init(
                text: interactor.cryptoCurrency.name,
                font: .main(.semibold, 20),
                color: .dashboardAssetTitle,
                accessibility: .id("\(AccessibilityId.titleLabelFormat)\(interactor.cryptoCurrency.displayCode)")
            )
        )
    }
    
    let pricePresenter: AssetPriceViewPresenter
    let sparklinePresenter: AssetSparklinePresenter
    let balancePresenter: AssetBalanceViewPresenter
    
    var cryptoCurrency: CryptoCurrency {
        interactor.cryptoCurrency
    }
    
    private let interactor: HistoricalBalanceCellInteractor
    
    init(interactor: HistoricalBalanceCellInteractor) {
        self.interactor = interactor
        sparklinePresenter = AssetSparklinePresenter(
            with: interactor.sparklineInteractor
        )
        pricePresenter = AssetPriceViewPresenter(
            interactor: interactor.priceInteractor,
            descriptors: .assetPrice(accessibilityIdSuffix: interactor.cryptoCurrency.displayCode)
        )
        balancePresenter = AssetBalanceViewPresenter(
            interactor: interactor.balanceInteractor,
            descriptors: .default(
                cryptoAccessiblitySuffix: AccessibilityId.cryptoBalanceLabelFormat,
                fiatAccessiblitySuffix: AccessibilityId.fiatBalanceLabelFormat)
        )
    }
}
