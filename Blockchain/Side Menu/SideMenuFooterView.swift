//
//  SideMenuFooterView.swift
//  Blockchain
//
//  Created by Alex McGregor on 2/25/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import PlatformUIKit

protocol SideMenuFooterDelegate: class {
    func footerView(_ footerView: SideMenuFooterView, selectedAction: SideMenuFooterView.Action)
}

/// `SideMenuFooterView` is shown at the base of `SideMenuViewController`. It's not
/// really a footer view (though it could be used as one). But it's only supposed to be shown at the bottom
/// of said screen (per the designs). 
class SideMenuFooterView: NibBasedView {
    
    enum Action {
        case pairWebWallet
        case logout
    }
    
    weak var delegate: SideMenuFooterDelegate?
    
    @IBOutlet fileprivate var pairButton: UIButton!
    @IBOutlet fileprivate var logoutButton: UIButton!
    
    @IBOutlet private var buttonHeightConstraints: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        buttonHeightConstraints.constant = SideMenuCell.defaultHeight
        
        let font = UIFont.mainMedium(DevicePresenter.type == .superCompact ? 14 : 17)
        
        pairButton.setTitle(LocalizationConstants.SideMenu.loginToWebWallet, for: .normal)
        pairButton.titleLabel?.font = font
        logoutButton.setTitle(LocalizationConstants.SideMenu.logout, for: .normal)
        logoutButton.titleLabel?.font = font
    }
    
    @IBAction func pairTapped(_ sender: UIButton) {
        delegate?.footerView(self, selectedAction: .pairWebWallet)
    }
    
    @IBAction func logoutTapped(_ sender: UIButton) {
        delegate?.footerView(self, selectedAction: .logout)
    }
}
