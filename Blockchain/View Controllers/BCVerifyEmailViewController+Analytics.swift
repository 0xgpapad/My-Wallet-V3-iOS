//
//  BCVerifyEmailViewController+Analytics.swift
//  Blockchain
//
//  Created by Daniel Huri on 04/10/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit

extension BCVerifyEmailViewController {
    
    @objc
    func reportUpdateButtonPressed() {
        AnalyticsEventRecorder.shared.record(event: AnalyticsEvents.KYC.kycVerifyEmailButtonClick)
    }
}
