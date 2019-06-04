//
//  PaxServiceProvider.swift
//  Blockchain
//
//  Created by Jack on 12/04/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import RxSwift
import EthereumKit
import ERC20Kit

protocol PAXDependencies {
    var assetAccountRepository: ERC20AssetAccountRepository<PaxToken> { get }
}

struct PAXServices: PAXDependencies {
    let assetAccountRepository: ERC20AssetAccountRepository<PaxToken>
    
    init(wallet: Wallet = WalletManager.shared.wallet) {
        let paxAccountClient = AnyERC20AccountAPIClient<PaxToken>()
        let service = ERC20AssetAccountDetailsService(
            with: wallet.ethereum,
            accountClient: paxAccountClient
        )
        self.assetAccountRepository = ERC20AssetAccountRepository(service: service)
    }
}

final class PAXServiceProvider {
    
    let services: PAXServices
    
    fileprivate let disposables = CompositeDisposable()
    
    static let shared = PAXServiceProvider.make()
    
    class func make() -> PAXServiceProvider {
        return PAXServiceProvider(services: PAXServices())
    }
    
    init(services: PAXServices) {
        self.services = services
    }
}
