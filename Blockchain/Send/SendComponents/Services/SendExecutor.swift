//
//  SendExecutor.swift
//  Blockchain
//
//  Created by Daniel Huri on 13/08/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import EthereumKit
import Foundation
import PlatformKit
import RxSwift

protocol SendExecuting: class {
    // TODO: Move outside this object
    func fetchHistoryIfNeeded()
    func send(value: CryptoValue, to address: String) -> Single<Void>
}

final class SendExecutor: SendExecuting {
    
    // MARK: - Properties
    
    private let asset: CryptoCurrency
    private let ethereumService: EthereumWalletServiceAPI
    
    private let disposeBag = DisposeBag()
    
    // MARK: - Setup
    
    init(asset: CryptoCurrency, ethereumService: EthereumWalletServiceAPI = EthereumWalletService.shared) {
        self.asset = asset
        self.ethereumService = ethereumService
    }
    
    // TODO: Move to another service
    /// Fetches history for account if needed
    func fetchHistoryIfNeeded() {
        switch asset {
        case .ethereum, .pax:
            ethereumService.fetchHistoryIfNeeded
                .subscribe()
                .disposed(by: disposeBag)
        case .algorand, .bitcoin, .bitcoinCash, .stellar:
            fatalError("assets do not support the new send logic")
        }
    }
    
    func send(value: CryptoValue, to address: String) -> Single<Void> {
        switch asset {
        case .ethereum:
            return send(ether: value, to: address)
        case .algorand, .bitcoin, .bitcoinCash, .pax, .stellar:
            fatalError("assets do not support the new send logic")
        }
    }
    
    private func send(ether: CryptoValue, to address: String) -> Single<Void> {
        let value: EthereumValue
        do {
            value = try EthereumValue(crypto: ether)
        } catch {
            return .error(error)
        }
        let address = EthereumAccountAddress(rawValue: address)!
        return self.ethereumService
            .buildTransaction(with: value, to: address.ethereumAddress)
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .flatMap(weak: self, { (self, candidate) -> Single<EthereumTransactionPublished> in
                self.ethereumService.send(transaction: candidate)
            })
            .mapToVoid()
    }
}
