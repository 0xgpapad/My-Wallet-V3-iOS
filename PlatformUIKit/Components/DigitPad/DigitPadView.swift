//
//  DigitPadView.swift
//  PlatformUIKit
//
//  Created by Daniel Huri on 07/06/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import RxCocoa

public final class DigitPadView: UIView {

    // MARK: - UI Properties
    
    @IBOutlet private var digitButtonViewArray: [DigitPadButtonView]!
    @IBOutlet private var backspaceButtonView: DigitPadButtonView!
    @IBOutlet private var customButtonView: DigitPadButtonView!
    
    // MARK: - Injected
    
    public var viewModel: DigitPadViewModel! {
        didSet {
            // Inject corresponding view model to each button view
            for (digitButtonViewModel, digitButtonView) in zip(viewModel.digitButtonViewModelArray, digitButtonViewArray) {
                digitButtonView.viewModel = digitButtonViewModel
            }
            customButtonView.viewModel = viewModel.customButtonViewModel
            backspaceButtonView.viewModel = viewModel.backspaceButtonViewModel
        }
    }
    
    // MARK: - Setup
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        fromNib()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        fromNib()
    }
}
