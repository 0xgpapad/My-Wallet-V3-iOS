//
//  RecoveryPhraseViewModel.swift
//  Blockchain
//
//  Created by AlexM on 1/15/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import RxRelay
import PlatformKit
import PlatformUIKit

class RecoveryPhraseViewModel {
    
    private typealias AccessibilityId = Accessibility.Identifier.Backup.RecoveryPhrase.View
    
    // MARK: - Private Properties
    
    private let mnemonicAPI: MnemonicAccessAPI
    private let disposeBag = DisposeBag()
    
    // MARK: - Public Properties
    
    var words: Observable<[LabelContent]> {
        wordsRelay.map {
            $0.enumerated().map {
                LabelContent(
                    text: $0.element,
                    font: .main(.semibold, 16.0),
                    color: .textFieldText,
                    accessibility: .id("\(AccessibilityId.word).\($0.offset)")
                )
            }
        }
    }
    
    let copyButtonViewModel: ButtonViewModel
    
    // MARK: - Private Properties
    
    private let wordsRelay = BehaviorRelay<[String]>(value: [])
    
    // MARK: - Init
    
    init(mnemonicAPI: MnemonicAccessAPI,
         mnemonicComponentsProviding: MnemonicComponentsProviding,
         pasteboarding: Pasteboarding = UIPasteboard.general) {
        
        mnemonicComponentsProviding
            .components
            .bind(to: wordsRelay)
            .disposed(by: disposeBag)
        
        self.mnemonicAPI = mnemonicAPI
        self.copyButtonViewModel = .secondary(with: LocalizationConstants.RecoveryPhraseScreen.copyToClipboard)

        copyButtonViewModel.tapRelay
            .withLatestFrom(mnemonicAPI.mnemonic.asObservable())
            .observeOn(MainScheduler.instance)
            .bind(weak: self) { (self, mnemonic) in
                pasteboarding.string = mnemonic
                
                let theme = ButtonViewModel.Theme(
                    backgroundColor: .primaryButton,
                    contentColor: .white,
                    text: LocalizationConstants.Address.copiedButton
                )
                self.copyButtonViewModel.animate(theme: theme)
                                
                let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                feedbackGenerator.prepare()
                feedbackGenerator.impactOccurred()
            }
            .disposed(by: disposeBag)
        
        copyButtonViewModel.tapRelay
            .debounce(
                .seconds(3),
                scheduler: ConcurrentDispatchQueueScheduler(qos: .background)
            )
            .observeOn(MainScheduler.instance)
            .bind(weak: self) { (self, mnemonic) in
                let theme = ButtonViewModel.Theme(
                    backgroundColor: .white,
                    contentColor: .primaryButton,
                    text: LocalizationConstants.RecoveryPhraseScreen.copyToClipboard
                )
                self.copyButtonViewModel.animate(theme: theme)
            }
            .disposed(by: disposeBag)
    }
}
