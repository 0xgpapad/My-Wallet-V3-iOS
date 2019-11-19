//
//  AirdropIntroCellPresenter.swift
//  Blockchain
//
//  Created by Daniel Huri on 18/11/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformUIKit

struct AirdropIntroCellData {
    
    struct CellContent {
        let text: String
        let accessibility: Accessibility
    }

    let title: CellContent
    let value: CellContent
}

final class AirdropIntroCellPresenter {
    
    // MARK: - Properties
    
    let title: LabelContent
    let value: LabelContent
    
    init(data: AirdropIntroCellData) {
        title = LabelContent(
            text: data.title.text,
            font: .mainMedium(14),
            color: .descriptionText,
            accessibility: data.title.accessibility
        )
        value = LabelContent(
            text: data.value.text,
            font: .mainMedium(14),
            color: .titleText,
            accessibility: data.value.accessibility
        )
    }
}
