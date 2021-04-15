//
//  TargetSelectionPageModel.swift
//  TransactionUIKit
//
//  Created by Alex McGregor on 2/24/21.
//  Copyright © 2021 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import RxSwift
import ToolKit

final class TargetSelectionPageModel {
    
    private let interactor: TargetSelectionInteractor
    private var mviModel: MviModel<TargetSelectionPageState, TargetSelectionAction>!
    
    var state: Observable<TargetSelectionPageState> {
        mviModel.state
    }
    
    init(initialState: TargetSelectionPageState = .empty, interactor: TargetSelectionInteractor) {
        self.interactor = interactor
        mviModel = MviModel(
            initialState: initialState,
            performAction: { [unowned self] (state, action) -> Disposable? in
                self.perform(previousState: state, action: action)
            }
        )
    }
    
    func destroy() {
        mviModel.destroy()
    }
    
    // MARK: - Internal methods
    
    func process(action: TargetSelectionAction) {
        mviModel.process(action: action)
    }
    
    func perform(previousState: TargetSelectionPageState, action: TargetSelectionAction) -> Disposable? {
        switch action {
        case .sourceAccountSelected(let account, let action):
            return processTargetListUpdate(sourceAccount: account, action: action)
        case .validateAddress(let address, let account):
            return validateCrypto(address: address, account: account)
        case .validateBitPayPayload(let value, let currency):
            return processBitPayValue(payload: value, currency: currency)
        case .destinationSelected,
             .availableTargets,
             .destinationConfirmed,
             .resetFlow,
             .returnToPreviousStep,
             .addressValidated,
             .destinationDeselected,
             .qrScannerButtonTapped,
             .validateQRScanner,
             .validBitPayInvoiceTarget:
            return nil
        }
    }
    
    private func processBitPayValue(payload: String, currency: CryptoCurrency) -> Disposable {
        interactor
            .getBitPayInvoiceTarget(data: payload, asset: currency)
            .subscribe(onSuccess: { [weak self] invoice in
                self?.process(action: .validBitPayInvoiceTarget(invoice))
                self?.process(action: .destinationConfirmed)
            })
    }
    
    private func processTargetListUpdate(sourceAccount: BlockchainAccount, action: AssetAction) -> Disposable {
        interactor
            .getAvailableTargetAccounts(sourceAccount: sourceAccount, action: action)
            .subscribe { [weak self] accounts in
                self?.process(action: .availableTargets(accounts))
            }
    }

    private func validateCrypto(address: String, account: CryptoAccount) -> Disposable {
        interactor
            .validateCrypto(address: address, account: account)
            .subscribe(onSuccess: { [weak self] (result) in
                guard case .success(let receiveAddress) = result else {
                    self?.process(action: .addressValidated(.invalid(address)))
                    return
                }
                self?.process(action: .addressValidated(.valid(receiveAddress)))
            })
    }
}
