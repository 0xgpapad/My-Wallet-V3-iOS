//
//  SendSpendableBalanceViewPresenter.swift
//  Blockchain
//
//  Created by Daniel Huri on 07/08/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import Foundation
import PlatformKit
import PlatformUIKit
import RxCocoa
import RxRelay
import RxSwift
import ToolKit

/// Presentation layer for spendable balance cell on send screen
final class SendSpendableBalanceViewPresenter {
    
    // MARK: - Exposed Properties
    
    /// An attributed string that visualize the spendable balance
    /// Streams on the main thread and replays the latest value.
    var attributedString: Driver<NSAttributedString> {
        attributesStringRelay.asDriver()
    }
    
    /// Tap receiver
    let tapRelay = PublishRelay<Void>()
    
    /// Streams the max spendable balance upon interaction
    let spendableBalanceTap: Observable<MoneyValuePair>

    // MARK: - Private Properties
    
    private let attributesStringRelay = BehaviorRelay<NSAttributedString>(value: NSAttributedString())
    private let disposeBag = DisposeBag()
    
    // MARK: - Injected
    
    private let interactor: SendSpendableBalanceInteracting
    private let analyticsRecorder: AnalyticsEventRelayRecording
    
    // MARK: - Setup
    
    init(asset: CryptoCurrency,
         interactor: SendSpendableBalanceInteracting,
         analyticsRecorder: AnalyticsEventRelayRecording = resolve()) {
        self.interactor = interactor
        self.analyticsRecorder = analyticsRecorder
        
        tapRelay
            .map { AnalyticsEvents.Send.sendFormUseBalanceClick(asset: asset) }
            .bindAndCatch(to: analyticsRecorder.recordRelay)
            .disposed(by: disposeBag)
        
        spendableBalanceTap = tapRelay.withLatestFrom(interactor.balance)
        
        // Construct the attributed string for the crypto balance
        interactor.balance
            .map { $0.base }
            .map { $0.toDisplayString(includeSymbol: true) }
            .map { value -> NSAttributedString in
                let font = Font(
                    .branded(.montserratRegular),
                    size: .custom(13.0)
                ).result
                
                // Setup prefix
                let prefixAttributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.darkGray
                ]
                let text = NSMutableAttributedString(
                    string: LocalizationConstants.Send.SpendableBalance.prefix,
                    attributes: prefixAttributes
                )
                
                // Setup suffix
                let suffixAttributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.brandSecondary
                ]
                let suffix = NSAttributedString(
                    string: value,
                    attributes: suffixAttributes
                )
                text.append(suffix)
                return text
            }
            .bindAndCatch(to: attributesStringRelay)
            .disposed(by: disposeBag)
    }
}
