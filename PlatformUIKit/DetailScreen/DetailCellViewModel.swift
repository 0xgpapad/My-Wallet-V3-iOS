//
//  DetailCellViewModel.swift
//  PlatformUIKit
//
//  Created by Alex McGregor on 8/5/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxDataSources

public struct DetailCellViewModel {
    public let presenter: DetailCellPresenter
    
    public init(presenter: DetailCellPresenter) {
        self.presenter = presenter
    }
}

extension DetailCellViewModel: IdentifiableType, Equatable {
    public var identity: AnyHashable {
        presenter.identity
    }
    
    public static func == (lhs: DetailCellViewModel, rhs: DetailCellViewModel) -> Bool {
        lhs.presenter == rhs.presenter
    }
}
