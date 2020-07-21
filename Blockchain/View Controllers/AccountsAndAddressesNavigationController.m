//
//  AccountsAndAddressesNavigationController.m
//  Blockchain
//
//  Created by Kevin Wu on 1/12/16.
//  Copyright © 2016 Blockchain Luxembourg S.A. All rights reserved.
//

#import "AccountsAndAddressesNavigationController.h"
#import "AccountsAndAddressesViewController.h"
#import "AccountsAndAddressesDetailViewController.h"
#import "SendBitcoinViewController.h"
#import "UIView+ChangeFrameAttribute.h"
#import "Blockchain-Swift.h"

@interface AccountsAndAddressesNavigationController () <WalletAddressesDelegate>
@end

@implementation AccountsAndAddressesNavigationController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.frame = [UIView rootViewSafeAreaFrameWithNavigationBar:YES tabBar:NO assetSelector:YES];

    self.warningButton = [[UIBarButtonItem alloc]
                          initWithImage:[UIImage imageNamed:@"warning"]
                          style:UIBarButtonItemStylePlain
                          target:self action:@selector(transferAllFundsWarningClicked)];

    WalletManager.sharedInstance.addressesDelegate = self;
}

- (void)reload
{
    if (![self.visibleViewController isMemberOfClass:[AccountsAndAddressesViewController class]] &&
        ![self.visibleViewController isMemberOfClass:[AccountsAndAddressesDetailViewController class]]) {
        [self popViewControllerAnimated:YES];
    }
    
    if (!self.view.window) {
        [self popToRootViewControllerAnimated:NO];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_KEY_RELOAD_ACCOUNTS_AND_ADDRESSES object:nil];
}

- (void)alertUserToTransferAllFunds
{
    AppFeatureConfiguration *transferFundsConfig = [AppFeatureConfigurator.shared configurationFor:AppFeatureTransferFundsFromImportedAddress];
    if (!transferFundsConfig.isEnabled) {
        return;
    }

    UIAlertController *alertToTransfer = [UIAlertController alertControllerWithTitle:BC_STRING_TRANSFER_FUNDS message:[NSString stringWithFormat:@"%@\n\n%@", BC_STRING_TRANSFER_FUNDS_DESCRIPTION_ONE, BC_STRING_TRANSFER_FUNDS_DESCRIPTION_TWO] preferredStyle:UIAlertControllerStyleAlert];
    [alertToTransfer addAction:[UIAlertAction actionWithTitle:BC_STRING_NOT_NOW style:UIAlertActionStyleCancel handler:nil]];
    [alertToTransfer addAction:[UIAlertAction actionWithTitle:BC_STRING_TRANSFER_FUNDS style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self transferAllFundsClicked];
    }]];
    
    [self presentViewController:alertToTransfer animated:YES completion:nil];
}

#pragma mark - Transfer Funds

- (void)transferAllFundsWarningClicked
{
    [self alertUserToTransferAllFunds];
}

- (void)transferAllFundsClicked
{
    [self dismissViewControllerAnimated:YES completion:^{
        [AppCoordinator.shared closeSideMenu];
    }];
    
    [[TransferAllCoordinator sharedInstance] startWithSendScreen];
}


#pragma mark WalletAddressesDelegate

- (void)didSetDefaultAccount
{
    [AssetAddressRepository.sharedInstance removeAllSwipeAddressesForAsset:LegacyAssetTypeBitcoin];
    [AssetAddressRepository.sharedInstance removeAllSwipeAddressesForAsset:LegacyAssetTypeBitcoinCash];
    [AppCoordinator.shared.tabControllerManager didSetDefaultAccount];
}

- (void)didGenerateNewAddress
{
    if ([self.visibleViewController isMemberOfClass:[AccountsAndAddressesViewController class]]) {
        AccountsAndAddressesViewController *accountsAndAddressesViewController = (AccountsAndAddressesViewController *)self.visibleViewController;
        [accountsAndAddressesViewController didGenerateNewAddress];
    }
}

- (void)returnToAddressesScreen
{
    [self popToRootViewControllerAnimated:YES];
}

- (AssetSelectorView *)assetSelectorView {
    if ([self.visibleViewController isMemberOfClass:[AccountsAndAddressesViewController class]]) {
        AccountsAndAddressesViewController *vc = (AccountsAndAddressesViewController *)self.visibleViewController;
        return vc.assetSelectorView;
    }
    return nil;
}

@end
