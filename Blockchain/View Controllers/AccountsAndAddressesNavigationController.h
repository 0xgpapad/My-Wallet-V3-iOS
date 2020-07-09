//
//  AccountsAndAddressesNavigationController.h
//  Blockchain
//
//  Created by Kevin Wu on 1/12/16.
//  Copyright © 2016 Blockchain Luxembourg S.A. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AssetSelectorView.h"

@interface AccountsAndAddressesNavigationController : UINavigationController
@property (nonatomic) UIBarButtonItem *warningButton;

- (AssetSelectorView *)assetSelectorView;
- (void)didGenerateNewAddress;
- (void)reload;
- (void)alertUserToTransferAllFunds;

@end
