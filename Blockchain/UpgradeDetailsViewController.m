//
//  UpgradeDetailsViewController.m
//  Blockchain
//
//  Created by Kevin Wu on 12/7/15.
//  Copyright © 2015 Qkos Services Ltd. All rights reserved.
//
#import "AppDelegate.h"
#import "UpgradeDetailsViewController.h"

@interface UpgradeDetailsViewController ()
@property (strong, nonatomic) IBOutlet UITextView *textView;
@property (strong, nonatomic) IBOutlet UIButton *upgradeWalletButton;
@end

@implementation UpgradeDetailsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = COLOR_BLOCKCHAIN_UPGRADE_BLUE;
    self.textView.text = BC_STRING_UPGRADE_DETAILS;
    self.textView.textColor = COLOR_UPGRADE_TEXT_BLUE;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.upgradeWalletButton.clipsToBounds = YES;
    self.upgradeWalletButton.layer.cornerRadius = 20;
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
}

- (IBAction)cancelUpgradeButtonTapped:(UIButton *)sender
{
    [self dismissSelf];
}

- (IBAction)upgradeWalletButtonTapped:(UIButton *)sender
{
    UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:BC_STRING_CONFIRM_UPGRADE message:BC_STRING_UPGRADE_WARNING preferredStyle:UIAlertControllerStyleAlert];
    [confirmAlert addAction:[UIAlertAction actionWithTitle:BC_STRING_UPGRADE style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [app.wallet loading_start_upgrade_to_hd];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [app closeSideMenu];
            [app.wallet performSelector:@selector(upgradeToHDWallet) withObject:nil afterDelay:0.1f];
        });
        [self dismissSelf];
    }]];
    [confirmAlert addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:confirmAlert animated:YES completion:nil];
}

- (void)dismissSelf
{
    UIViewController *viewController = self.presentingViewController;
    while (viewController.presentingViewController) {
        viewController = viewController.presentingViewController;
    }
    [viewController dismissViewControllerAnimated:YES completion:NULL];
}

@end
