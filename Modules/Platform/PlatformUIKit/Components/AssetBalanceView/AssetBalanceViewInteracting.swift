// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import PlatformKit
import RxSwift

public protocol AssetBalanceViewInteracting: class {
    var state: Observable<AssetBalanceViewModel.State.Interaction> { get }
}

public protocol AssetBalanceTypeViewInteracting: AssetBalanceViewInteracting {
    var accountType: SingleAccountType { get }
}
