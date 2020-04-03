//
//  LocationUpdateAPI.swift
//  Blockchain
//
//  Created by Alex McGregor on 8/8/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import NetworkKit
import PlatformKit

typealias LocationUpdateCompletion = ((Error?) -> Void)

enum LocationUpdateError: Error {
    case noPostalCode
    case noAddress
    case noCity
    case noCountry
}

protocol LocationUpdateAPI {
    func updateAddress(address: UserAddress, with completion: @escaping LocationUpdateCompletion)
}

class LocationUpdateService: NSObject, LocationUpdateAPI {

    private var disposable: Disposable?

    deinit {
        disposable?.dispose()
    }

    func updateAddress(address: UserAddress, with completion: @escaping LocationUpdateCompletion) {
        disposable = NabuAuthenticationService.shared
            .tokenString
            .flatMapCompletable { token in
                let headers = [HttpHeaderField.authorization: token]
                let payload = KYCUpdateAddressRequest(address: address)
                return KYCNetworkRequest.request(
                    put: .updateAddress,
                    parameters: payload,
                    headers: headers
                )
            }
            .observeOn(MainScheduler.instance)
            .subscribe(onCompleted: {
                completion(nil)
            }, onError: { error in
                completion(error)
            })
    }
}
