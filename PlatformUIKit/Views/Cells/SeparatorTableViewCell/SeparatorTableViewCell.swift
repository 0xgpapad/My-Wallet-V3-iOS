//
//  SeparatorTableViewCell.swift
//  PlatformUIKit
//
//  Created by AlexM on 1/28/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

/// A simple cell displaying a single 1pt line with `0` padding.
public final class SeparatorTableViewCell: UITableViewCell {
    
    // MARK: - Private IBOutlets
    
    @IBOutlet private var lineView: UIView!
    
    // MARK: - Lifecycle
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        lineView.backgroundColor = .background
    }
}
