//
//  TargetSelectionPageInteractor.swift
//  TransactionUIKit
//
//  Created by Dimitrios Chatzieleftheriou on 01/02/2021.
//  Copyright © 2021 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import Localization
import PlatformKit
import PlatformUIKit
import RIBs
import RxCocoa
import RxSwift
import ToolKit

protocol TargetSelectionPageRouting: ViewableRouting {
}

protocol TargetSelectionPageListener: AnyObject {
    func didSelect(blockchainAccount: BlockchainAccount)
    func didTapBack()
    func didTapClose()
}

final class TargetSelectionPageInteractor: PresentableInteractor<TargetSelectionPagePresentable>,
                                           TargetSelectionPageInteractable {

    weak var router: TargetSelectionPageRouting?

    // MARK: - Private Properties
    
    private let accountProvider: SourceAndTargetAccountProviding
    private let targetSelectionPageModel: TargetSelectionPageModel
    private let action: AssetAction
    private let didSelect: AccountPickerDidSelect?
    weak var listener: TargetSelectionPageListener?
    
    private let disposeBag = DisposeBag()

    // MARK: - Init

    init(targetSelectionPageModel: TargetSelectionPageModel,
         presenter: TargetSelectionPagePresentable,
         accountProvider: SourceAndTargetAccountProviding,
         listener: TargetSelectionListenerBridge,
         action: AssetAction) {
        self.action = action
        self.targetSelectionPageModel = targetSelectionPageModel
        self.accountProvider = accountProvider
        switch listener {
        case .simple(let didSelect):
            self.didSelect = didSelect
            self.listener = nil
        case .listener(let listener):
            self.didSelect = nil
            self.listener = listener
        }
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        super.didBecomeActive()
        
        /// Listens to the `step` which
        /// triggers routing to a new screen or ending the flow
        targetSelectionPageModel
            .state
            .distinctUntilChanged(\.step)
            .observeOn(MainScheduler.asyncInstance)
            .subscribe { [weak self] state in
                self?.handleStateChange(newState: state)
            }
            .disposeOnDeactivate(interactor: self)
        
        /// Fetch the source account provided.
        accountProvider
            .sourceAccount
            .map { account -> CryptoAccount in
                guard let crypto = account else {
                    fatalError("Expected a source account")
                }
                return crypto
            }
            .asObservable()
            .subscribe(onNext: { account in
                self.targetSelectionPageModel.process(action: .sourceAccountSelected(account, self.action))
            })
            .disposed(by: disposeBag)
        
        let interactorState = targetSelectionPageModel
            .state
            .observeOn(MainScheduler.instance)
            .scan(.empty) { (state, updater) -> TargetSelectionPageInteractor.State in
                guard let sourceAccount = updater.sourceAccount as? SingleAccount else {
                    fatalError("You should have a source account.")
                }
                let targets = (updater.availableTargets ?? [])
                    .compactMap { $0 as? SingleAccount }
                
                let interactors: TargetSelectionPageInteractor.State.Interactors = .init(
                    sourceAccount: sourceAccount,
                    availableTargets: targets,
                    target: updater.destination as? SingleAccount
                )
                
                return state
                    /// Update the `Interactors` for the cells.
                    .update(keyPath: \.interactors, value: interactors)
                    /// Update the enabled state of the `Next` button.
                    .update(keyPath: \.actionButtonEnabled, value: updater.nextEnabled)
            }
            .asDriverCatchError()
        
        presenter.connect(state: interactorState)
            .drive(onNext: handle(effects:))
            .disposeOnDeactivate(interactor: self)
    }

    // MARK: - Private methods

    private func handle(effects: Effects) {
        switch effects {
        case .select(let account):
            targetSelectionPageModel.process(action: .destinationSelected(account))
        case .back,
             .closed:
            targetSelectionPageModel.process(action: .resetFlow)
        case .next:
            targetSelectionPageModel.process(action: .destinationConfirmed)
        case .none:
            break
        }
    }
    
    private var initialStep: Bool = true
    private func handleStateChange(newState: TargetSelectionPageState) {
        if !initialStep, newState.step == TargetSelectionPageStep.initial {
            finishFlow()
        } else {
            initialStep = false
            showFlowStep(newState: newState)
        }
    }

    private func finishFlow() {
        targetSelectionPageModel.process(action: .resetFlow)
    }
    
    private func showFlowStep(newState: TargetSelectionPageState) {
        guard !newState.isGoingBack else {
            listener?.didTapBack()
            return
        }
        switch newState.step {
        case .initial:
            break
        case .closed:
            targetSelectionPageModel.destroy()
            listener?.didTapClose()
        case .complete:
            guard let account = newState.destination else {
                fatalError("Expected a destination acount.")
            }
            didSelect?(account)
            listener?.didSelect(blockchainAccount: account)
        }
    }
    
    private func initialState() -> TargetSelectionPageState {
        TargetSelectionPageState(nextEnabled: false, destination: nil)
    }
}

extension TargetSelectionPageInteractor {
    struct State: StateType {
        static let empty = State(actionButtonEnabled: false)
        
        /// A model holding interactors for all `CellItems` on the Target Selection screen.
        /// `sourceInteractor` is the `From` account.
        /// `destinationInteractors` is all possible targets including the selected target.
        struct Interactors {
            static let empty = Interactors(sourceInteractor: nil, destinationInteractors: [])
            let sourceInteractor: TargetSelectionPageCellItem.Interactor?
            let destinationInteractors: [TargetSelectionPageCellItem.Interactor]
            
            private init(sourceInteractor: TargetSelectionPageCellItem.Interactor?,
                         destinationInteractors: [TargetSelectionPageCellItem.Interactor]) {
                self.sourceInteractor = sourceInteractor
                self.destinationInteractors = destinationInteractors
            }
            
            init(sourceAccount: SingleAccount, availableTargets: [SingleAccount], target: SingleAccount?) {
                sourceInteractor = .singleAccount(sourceAccount, AccountAssetBalanceViewInteractor(account: sourceAccount))
                var destinations: [TargetSelectionPageCellItem.Interactor] = availableTargets.map { .singleAccountAvailableTarget($0) }
                /// If there is a target selected, filter it out from `destinations`
                /// and append it as a `singleAccountSelection`. This will show the
                /// radio cell as selected.
                if let account = target {
                    destinations = destinations.filter { $0.account.id != account.id }
                    destinations.append(.singleAccountSelection(account))
                }
                /// Order the destinations alphabetically.
                destinationInteractors = destinations.sorted { $0.account.label < $1.account.label }
            }
        }
        
        var interactors: Interactors
        var actionButtonEnabled: Bool
        
        private init(interactors: Interactors = .empty, actionButtonEnabled: Bool) {
            self.interactors = interactors
            self.actionButtonEnabled = actionButtonEnabled
        }
    }

    enum Effects {
        case select(BlockchainAccount)
        case next
        case back
        case closed
        case none
    }
}
