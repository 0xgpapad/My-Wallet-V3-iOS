//
//  WalletActionScreenPresenting.swift
//  Blockchain
//
//  Created by AlexM on 2/27/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import Localization
import PlatformKit
import RxCocoa
import RxSwift

public protocol WalletActionScreenPresenting: class {
    
    var selectionRelay: PublishRelay<WalletActionCellType> { get }
    
    var sections: Observable<[WalletActionItemsSectionViewModel]> { get }
    
    /// Presenter for `balance` cell
    var assetBalanceViewPresenter: CurrentBalanceCellPresenter { get }
    
    /// The selected `CryptoCurrency`
    var currency: CurrencyType { get }
}
