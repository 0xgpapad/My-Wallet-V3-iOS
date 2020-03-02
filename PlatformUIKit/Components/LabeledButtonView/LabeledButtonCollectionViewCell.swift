//
//  LabeledButtonCollectionViewCell.swift
//  PlatformUIKit
//
//  Created by Daniel Huri on 23/01/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

/// Represents a labeled-button embedded inside a `UICollectionViewCell`
final class LabeledButtonCollectionViewCell<ViewModel: LabeledButtonViewModelAPI>: UICollectionViewCell {
    
    // MARK: - Properties
    
    var viewModel: ViewModel! {
        didSet {
            labeledButtonView.viewModel = viewModel
        }
    }
    
    private let labeledButtonView = LabeledButtonView<ViewModel>()
    
    // MARK: - Setup
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(labeledButtonView)
        labeledButtonView.fillSuperview()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        viewModel = nil
    }
}
