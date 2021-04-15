//
//  RecordingError.swift
//  Blockchain
//
//  Created by Daniel Huri on 24/06/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

public enum BreadcrumbError: Error {

    /// Breadcrumb (no information)
    case breadcrumb
}

public enum UIOperationError: Error {

    /// Changing the UI on a background thread
    case changingUIOnBackgroundThread
}
