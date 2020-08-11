//
//  Send.swift
//  PlatformUIKit
//
//  Created by Daniel on 06/08/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import RxCocoa
import ToolKit
import PlatformKit

public final class SendAuxiliaryView: UIView {
    
    // MARK: - Properties
    
    public var presenter: SendAuxililaryViewPresenter! {
        didSet {
            maxButtonView.viewModel = presenter?.maxButtonViewModel
            availableBalanceView.presenter = presenter?.availableBalanceContentViewPresenter
        }
    }
    
    private let availableBalanceView: ContentLabelView
    private let maxButtonView: ButtonView
        
    public init() {
        availableBalanceView = ContentLabelView()
        maxButtonView = ButtonView()
        
        super.init(frame: UIScreen.main.bounds)
        
        addSubview(availableBalanceView)
        addSubview(maxButtonView)
        
        availableBalanceView.layoutToSuperview(.centerY)
        availableBalanceView.layoutToSuperview(.leading, offset: Spacing.outer)
        
        maxButtonView.layout(dimension: .height, to: 30)
        maxButtonView.layoutToSuperview(.trailing, offset: -Spacing.outer)
        maxButtonView.layoutToSuperview(.centerY)
    }
    
    required init?(coder: NSCoder) { unimplemented() }
}
