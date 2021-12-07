// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import MoneyKit
import PlatformKit
import RxSwift

final class AddBankInteractor: AddSpecificPaymentMethodInteractorAPI {

    private let beneficiariesService: BeneficiariesServiceAPI
    private let fiatCurrency: FiatCurrency

    var isAbleToAddNew: Observable<Bool> {
        let fiatCurrency = fiatCurrency
        return beneficiariesService.availableCurrenciesForBankLinkage
            .map { currencies -> Bool in
                currencies.contains(fiatCurrency)
            }
            .catchAndReturn(false)
            .share(replay: 1)
    }

    init(
        beneficiariesService: BeneficiariesServiceAPI,
        fiatCurrency: FiatCurrency
    ) {
        self.fiatCurrency = fiatCurrency
        self.beneficiariesService = beneficiariesService
    }
}
