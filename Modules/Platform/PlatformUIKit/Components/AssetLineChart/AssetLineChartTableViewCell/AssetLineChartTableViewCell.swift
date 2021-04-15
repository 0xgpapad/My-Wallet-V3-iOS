//
//  AssetLineChartTableViewCell.swift
//  Blockchain
//
//  Created by AlexM on 11/13/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

public final class AssetLineChartTableViewCell: UITableViewCell {
    
    public var presenter: AssetLineChartTableViewCellPresenter! {
        didSet {
            assetLineChartView.presenter = presenter?.presenterContainer
            segmentedView.viewModel = presenter?.priceWindowPresenter.segmentedViewModel
        }
    }
    
    @IBOutlet private var assetLineChartView: AssetLineChartView!
    @IBOutlet private var segmentedView: SegmentedView!
    
    // MARK: - Lifecycle
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        presenter = nil
    }
}
