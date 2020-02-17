//
//  SendViewController.m
//  Blockchain
//
//  Created by Ben Reeves on 17/03/2012.
//  Copyright (c) 2012 Blockchain Luxembourg S.A. All rights reserved.
//

#import "SendBitcoinViewController.h"
#import "Wallet.h"
#import "BCAddressSelectionView.h"
#import "TabViewController.h"
#import "UITextField+Blocks.h"
#import "UIViewController+AutoDismiss.h"
#import "LocalizationConstants.h"
#import "TransactionsBitcoinViewController.h"
#import "UIView+ChangeFrameAttribute.h"
#import "TransferAllFundsBuilder.h"
#import "BCNavigationController.h"
#import "BCFeeSelectionView.h"
#import "BCConfirmPaymentViewModel.h"
#import "Blockchain-Swift.h"
#import "NSNumberFormatter+Currencies.h"

@class BridgeAddressFetcher;
@class BridgeBitpayService;
@class BridgeAnalyticsRecorder;

@import BitcoinKit;

typedef enum {
    SendTransactionTypeRegular = 100,
    SendTransactionTypeSweep = 200,
    SendTransactionTypeSweepAndConfirm = 300,
} SendTransactionType;

typedef enum {
    RejectionTypeDecline,
    RejectionTypeCancel
} RejectionType;

@interface QRCodeScannerSendViewController ()
- (void)stopReadingQRCode;
@end

@interface SendBitcoinViewController () <UITextFieldDelegate, TransferAllFundsDelegate, FeeSelectionDelegate, ConfirmPaymentViewDelegate, LegacyPrivateKeyDelegate>

@property (strong, nonatomic) IBOutlet NSLayoutConstraint *continueButtonTopConstraint;

@property (nonatomic) SendTransactionType transactionType;

@property (nonatomic, readwrite) DestinationAddressSource addressSource;

@property (nonatomic) uint64_t recommendedForcedFee;
@property (nonatomic) uint64_t feeFromTransactionProposal;
@property (nonatomic) uint64_t lastDisplayedFee;
@property (nonatomic) uint64_t dust;
@property (nonatomic) uint64_t txSize;

@property (nonatomic) uint64_t amountFromURLHandler;

@property (nonatomic) uint64_t upperRecommendedLimit;
@property (nonatomic) uint64_t lowerRecommendedLimit;
@property (nonatomic) uint64_t estimatedTransactionSize;

@property (nonatomic) FeeType feeType;
@property (nonatomic) UILabel *feeTypeLabel;
@property (nonatomic) UILabel *feeDescriptionLabel;
@property (nonatomic) UILabel *feeAmountLabel;
@property (nonatomic) UILabel *feeWarningLabel;
@property (nonatomic) UIButton *exchangeAddressButton;
@property (nonatomic) NSDictionary *fees;

@property (nonatomic) NSString *noteToSet;

@property (nonatomic) BOOL isReloading;
@property (nonatomic) BOOL shouldReloadFeeAmountLabel;

@property (nonatomic, copy) void (^getTransactionFeeSuccess)(void);
@property (nonatomic, copy) void (^getDynamicFeeError)(void);

@property (nonatomic, copy) void (^onViewDidLoad)(void);

@property (nonatomic) TransferAllFundsBuilder *transferAllPaymentBuilder;

@property (nonatomic) BCNavigationController *contactRequestNavigationController;

@property (nonatomic) SendExchangeAddressStatePresenter *exchangeAddressPresenter;
@property (nonatomic) BridgeBitpayService *bitpayService;
@property (nonatomic) BridgeAnalyticsRecorder *analyticsRecorder;

@property (nonatomic, strong) ExchangeAddressViewModel *exchangeAddressViewModel;

@property (nonatomic, strong) BridgeDeepLinkQRCodeRouter *deepLinkQRCodeRouter;

@property (nonatomic) NSString *bitpayMerchant;
@property (nonatomic) NSDate *bitpayExpiration;
@property (nonatomic) NSTimer *bitpayTimer;
@property (nonatomic) UILabel *bitpayLabel;
@property (nonatomic) UILabel *bitpayTimeRemainingText;
@property (nonatomic) UIImageView *bitpayLogo;
@property (nonatomic) BCLine *lineBelowBitpayLabel;

@property (nonatomic) BOOL isBitpayPayPro;

@end


@implementation SendBitcoinViewController

uint64_t amountInSatoshi = 0.0;
uint64_t availableAmount = 0.0;

BOOL displayingLocalSymbolSend;

#pragma mark - Lifecycle

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    sendProgressModalText.text = nil;

    [[NSNotificationCenter defaultCenter] addObserverForName:NOTIFICATION_KEY_LOADING_TEXT object:nil queue:nil usingBlock:^(NSNotification * notification) {
        self->sendProgressModalText.text = [notification object];
    }];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    CGFloat safeAreaInsetTop = 20;
    CGFloat safeAreaInsetBottom = 0;
    CGFloat assetSelectorHeight = 36;
    CGFloat navBarHeight = [ConstantsObjcBridge defaultNavigationBarHeight];
    CGFloat tabBarHeight = 49;
    if (@available(iOS 11.0, *)) {
        safeAreaInsetTop = window.rootViewController.view.safeAreaInsets.top;
        safeAreaInsetBottom = window.rootViewController.view.safeAreaInsets.bottom;
    }
    CGFloat topConstant = window.bounds.size.height - safeAreaInsetTop - navBarHeight - assetSelectorHeight - tabBarHeight - safeAreaInsetBottom;
    _continueButtonTopConstraint.constant = topConstant - BUTTON_HEIGHT - 20;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_LOADING_TEXT object:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.deepLinkQRCodeRouter = [[BridgeDeepLinkQRCodeRouter alloc] init];
    
    self.exchangeAddressPresenter = [[SendExchangeAddressStatePresenter alloc] initWithAssetType:self.assetType];
    
    self.bitpayService = [[BridgeBitpayService alloc] init];
    self.analyticsRecorder = [[BridgeAnalyticsRecorder alloc] init];

    self.view.frame = [UIView rootViewSafeAreaFrameWithNavigationBar:YES tabBar:YES assetSelector:YES];

    [containerView changeWidth:self.view.frame.size.width];

    [selectAddressTextField changeWidth:self.view.frame.size.width - fromLabel.frame.size.width - 15 - 13 - selectFromButton.frame.size.width];
    [selectFromButton changeXPosition:self.view.frame.size.width - selectFromButton.frame.size.width];

    [addressBookButton changeXPosition:self.view.frame.size.width - addressBookButton.frame.size.width];

    CGFloat exchangeAddressButtonWidth = 50.0f;
    UIButton *exchangeAddressButton = [[UIButton alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - addressBookButton.bounds.size.width - exchangeAddressButtonWidth, addressBookButton.frame.origin.y, exchangeAddressButtonWidth, addressBookButton.bounds.size.height)];
    [exchangeAddressButton setImage:[UIImage imageNamed:@"exchange-icon-small"] forState:UIControlStateNormal];
    [exchangeAddressButton addTarget:self action:@selector(exchangeAddressButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    exchangeAddressButton.hidden = true;
    [self.view addSubview:exchangeAddressButton];
    self.exchangeAddressButton = exchangeAddressButton;
    [self.exchangeAddressButton changeXPosition:self.view.bounds.size.width - addressBookButton.frame.size.width - self.exchangeAddressButton.bounds.size.width];

    self.bitpayLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, lineBelowFeeField.superview.frame.origin.y + lineBelowFeeField.superview.frame.size.height + 2, self.view.frame.size.width, 64)];
    [self.view addSubview:self.bitpayLabel];
    self.bitpayLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_SMALL];
    self.bitpayLabel.adjustsFontSizeToFitWidth = YES;
    self.bitpayLabel.textColor = UIColor.gray5;
    self.bitpayLabel.hidden = YES;
    
    self.bitpayTimeRemainingText = [[UILabel alloc] initWithFrame:CGRectMake(15, lineBelowFeeField.superview.frame.origin.y + lineBelowFeeField.superview.frame.size.height + 2, self.view.frame.size.width, 21)];
    [self.view addSubview:self.bitpayTimeRemainingText];
    self.bitpayTimeRemainingText.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_EXTRA_EXTRA_SMALL];
    self.bitpayTimeRemainingText.adjustsFontSizeToFitWidth = YES;
    self.bitpayTimeRemainingText.textColor = UIColor.gray3;
    self.bitpayTimeRemainingText.hidden = YES;
    
    self.bitpayLogo = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 83, lineBelowFeeField.superview.frame.origin.y + lineBelowFeeField.superview.frame.size.height + 23, 68, 24)];
    self.bitpayLogo.image = [UIImage imageNamed:@"bitpay-logo"];
    [self.view addSubview:self.bitpayLogo];
    self.bitpayLogo.hidden = YES;
    
    self.lineBelowBitpayLabel = [[BCLine alloc] initWithFrame:CGRectMake(16, lineBelowFeeField.superview.frame.origin.y + lineBelowFeeField.superview.frame.size.height + 64, self.view.frame.size.width, 1)];
    self.lineBelowBitpayLabel.backgroundColor = UIColor.gray1;
    self.lineBelowBitpayLabel.hidden = YES;
    [self.view addSubview:self.lineBelowBitpayLabel];

    
    [toField changeWidth:self.view.frame.size.width - toLabel.frame.size.width - addressBookButton.frame.size.width - self.exchangeAddressButton.bounds.size.width - 16];
    
    destinationAddressIndicatorLabel = [[UILabel alloc] initWithFrame:toField.frame];
    destinationAddressIndicatorLabel.font = selectAddressTextField.font;
    destinationAddressIndicatorLabel.textColor = selectAddressTextField.textColor;
    NSString *symbol = [AssetTypeLegacyHelper symbolFor:self.assetType];
    destinationAddressIndicatorLabel.text = [NSString stringWithFormat:[LocalizationConstantsObjcBridge sendAssetExchangeDestination], symbol];
    destinationAddressIndicatorLabel.hidden = true;
    [self.view addSubview:destinationAddressIndicatorLabel];
    
    CGFloat amountFieldWidth = (self.view.frame.size.width - btcLabel.frame.origin.x - btcLabel.frame.size.width - fiatLabel.frame.size.width - 15 - 13 - 8 - 13)/2;
    btcAmountField.frame = CGRectMake(btcAmountField.frame.origin.x, btcAmountField.frame.origin.y, amountFieldWidth, btcAmountField.frame.size.height);
    fiatLabel.frame = CGRectMake(btcAmountField.frame.origin.x + btcAmountField.frame.size.width + 8, fiatLabel.frame.origin.y, fiatLabel.frame.size.width, fiatLabel.frame.size.height);
    fiatAmountField.frame = CGRectMake(fiatLabel.frame.origin.x + fiatLabel.frame.size.width + 13, fiatAmountField.frame.origin.y, amountFieldWidth, fiatAmountField.frame.size.height);
    
    btcAmountField.inputAccessoryView = amountKeyboardAccessoryView;
    fiatAmountField.inputAccessoryView = amountKeyboardAccessoryView;
    toField.inputAccessoryView = amountKeyboardAccessoryView;
    feeField.inputAccessoryView = amountKeyboardAccessoryView;
    
    fromLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_SMALL];
    selectAddressTextField.font = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_SMALL];
    destinationAddressIndicatorLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_SMALL];
    toLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_SMALL];
    toField.font = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_SMALL];
    btcLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_SMALL];
    btcAmountField.font = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_SMALL];
    fiatLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_SMALL];
    fiatAmountField.font = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_SMALL];
    feeLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_SMALL];
    feeField.font = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_SMALL];
    
    [self setupFeeLabels];

    [self setupFeeWarningLabelFrameSmall];

    [feeOptionsButton changeXPosition:self.view.frame.size.width - feeOptionsButton.frame.size.width];

    self.feeDescriptionLabel.frame = CGRectMake(feeField.frame.origin.x, feeField.center.y, btcAmountField.frame.size.width*2/3, 20);
    self.feeDescriptionLabel.adjustsFontSizeToFitWidth = YES;
    self.feeTypeLabel.frame = CGRectMake(feeField.frame.origin.x, feeField.center.y - 20, btcAmountField.frame.size.width*2/3, 20);
    CGFloat amountLabelOriginX = self.feeTypeLabel.frame.origin.x + self.feeTypeLabel.frame.size.width;
    self.feeTypeLabel.adjustsFontSizeToFitWidth = YES;
    self.feeAmountLabel.frame = CGRectMake(amountLabelOriginX, feeField.center.y - 10, feeOptionsButton.frame.origin.x - amountLabelOriginX, 20);
    self.feeAmountLabel.adjustsFontSizeToFitWidth = YES;

    [feeField changeWidth:self.feeAmountLabel.frame.origin.x - (feeLabel.frame.origin.x + feeLabel.frame.size.width) - (feeField.frame.origin.x - (feeLabel.frame.origin.x + feeLabel.frame.size.width))];
    
    fundsAvailableButton.titleLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_EXTRA_SMALL];
    [fundsAvailableButton setTitleColor:UIColor.brandSecondary forState:UIControlStateNormal];
    fundsAvailableButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    
    feeField.delegate = self;
        
    toField.placeholder =  self.assetType == LegacyAssetTypeBitcoin ? BC_STRING_ENTER_BITCOIN_ADDRESS_OR_SELECT : BC_STRING_ENTER_BITCOIN_CASH_ADDRESS_OR_SELECT;
    feeField.placeholder = BC_STRING_SATOSHI_PER_BYTE_ABBREVIATED;
    btcAmountField.placeholder = [NSString stringWithFormat:BTC_PLACEHOLDER_DECIMAL_SEPARATOR_ARGUMENT, [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];
    fiatAmountField.placeholder = [NSString stringWithFormat:FIAT_PLACEHOLDER_DECIMAL_SEPARATOR_ARGUMENT, [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];

    toField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [toField setReturnKeyType:UIReturnKeyDone];
    
    CGFloat continueButtonOriginY = [self continuePaymentButtonOriginY];
    continuePaymentButton.frame = CGRectMake(0, continueButtonOriginY, self.view.frame.size.width - 40, BUTTON_HEIGHT);
    
    if (self.assetType == LegacyAssetTypeBitcoin) {
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(feeOptionsClicked:)];
        [feeTappableView addGestureRecognizer:tapGestureRecognizer];
    }
    
    [self reload];
    
    if (self.onViewDidLoad) {
        self.onViewDidLoad();
        self.onViewDidLoad = nil;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.isReloading) {
        return;
    }
    
    availableAmount = [[WalletManager.sharedInstance.wallet getBalanceForAccount:self.fromAccount assetType:self.assetType] longLongValue];
}

- (void)setupFeeLabels
{
    self.feeDescriptionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.feeDescriptionLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_SMALL];
    self.feeDescriptionLabel.textColor = UIColor.gray2;
    [bottomContainerView addSubview:self.feeDescriptionLabel];
    
    self.feeTypeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.feeTypeLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_SMALL];
    self.feeTypeLabel.textColor = UIColor.gray5;
    [bottomContainerView addSubview:self.feeTypeLabel];
    
    self.feeAmountLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.feeAmountLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_SMALL];
    self.feeAmountLabel.textColor = UIColor.gray5;
    [bottomContainerView addSubview:self.feeAmountLabel];
    
    self.feeWarningLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    // Use same font size for all screen sizes
    self.feeWarningLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_EXTRA_SMALL];
    self.feeWarningLabel.textColor = UIColor.error;
    self.feeWarningLabel.numberOfLines = 2;
    [bottomContainerView addSubview:self.feeWarningLabel];
}

- (void)resetPayment
{
    self.surgeIsOccurring = NO;
    self.dust = 0;

    [WalletManager.sharedInstance.wallet createNewPayment:self.assetType];
    [self resetFromAddress];

    TabControllerManager *tabControllerManager = [AppCoordinator sharedInstance].tabControllerManager;
    if (tabControllerManager.tabViewController.activeViewController == self && !tabControllerManager.tabViewController.presentedViewController) {
        [[ModalPresenter sharedInstance] closeModalWithTransition:kCATransitionPush];
    }
    
    self.transactionType = SendTransactionTypeRegular;
}

- (void)resetFromAddress
{
    self.fromAddress = @"";
    if ([WalletManager.sharedInstance.wallet hasAccount]) {
        // Default setting: send from default account
        self.sendFromAddress = false;
        int defaultAccountIndex = [WalletManager.sharedInstance.wallet getDefaultAccountIndexForAssetType:self.assetType];
        self.fromAccount = defaultAccountIndex;
        if (self.isReloading) return; // didSelectFromAccount will be called in reloadAfterMultiAddressResponse
        [self didSelectFromAccount:self.fromAccount assetType:self.assetType];
    }
    else {
        // Default setting: send from any address
        self.sendFromAddress = true;
        if (self.isReloading) return; // didSelectFromAddress will be called in reloadAfterMultiAddressResponse
        [self didSelectFromAddress:self.fromAddress];
    }
}

- (void)clearToAddressAndAmountFields
{
    self.toAddress = @"";
    toField.text = @"";
    amountInSatoshi = 0;
    btcAmountField.text = @"";
    fiatAmountField.text = @"";
    feeField.text = @"";
}

- (void)reload
{
    self.isReloading = YES;
    
    [self clearToAddressAndAmountFields];

    if (![WalletManager.sharedInstance.wallet isInitialized]) {
        DLog(@"SendViewController: Wallet not initialized");
        return;
    }
    
    if (!WalletManager.sharedInstance.latestMultiAddressResponse) {
        DLog(@"SendViewController: No latest response");
        return;
    }
    
    [self resetPayment];
    
    // Default: send to address
    self.sendToAddress = true;
    
    [self hideSelectFromAndToButtonsIfAppropriate];
    
    [self populateFieldsFromURLHandlerIfAvailable];
    
    [self reloadFromAndToFields];
    
    [self reloadSymbols];
    
    [self updateFundsAvailable];
    
    [self enablePaymentButtons];
    
    [self setupFees];
    
    [self enableInputs];
    
    [self.bitpayTimer invalidate];
    
    self.bitpayLabel.hidden = YES;
    self.bitpayLogo.hidden = YES;
    self.bitpayTimeRemainingText.hidden = YES;
    self.lineBelowBitpayLabel.hidden = YES;
    
    sendProgressCancelButton.hidden = YES;
    
    [self enableAmountViews];
    [self enableToField];
    
    self.isSending = NO;
    self.isReloading = NO;

    self.isBitpayPayPro = NO;
    
    self.noteToSet = nil;
    
    __weak SendBitcoinViewController *weakSelf = self;
    
    self.exchangeAddressPresenter = [[SendExchangeAddressStatePresenter alloc] initWithAssetType:self.assetType];
    
    [self.exchangeAddressPresenter fetchAddressViewModelWithCompletion:^(ExchangeAddressViewModel * _Nonnull viewModel) {
        weakSelf.exchangeAddressViewModel = viewModel;
        weakSelf.exchangeAddressButton.hidden = viewModel.isExchangeLinked == NO;
    }];
}

- (void)reloadAfterMultiAddressResponse
{
    [self hideSelectFromAndToButtonsIfAppropriate];
    
    [self reloadLocalAndBtcSymbolsFromLatestResponse];
    
    if (self.sendFromAddress) {
        [self changePaymentFromAddress:self.fromAddress];
    } else {
        [self changePaymentFromAccount:self.fromAccount];
    }
    
    if (self.shouldReloadFeeAmountLabel) {
        self.shouldReloadFeeAmountLabel = NO;
        if (self.feeAmountLabel.text) {
            [self updateFeeAmountLabelText:self.lastDisplayedFee];
        }
    }
}

- (void)reloadFeeAmountLabel
{
    self.shouldReloadFeeAmountLabel = YES;
}

- (void)reloadSymbols
{
    [self reloadLocalAndBtcSymbolsFromLatestResponse];
    [self updateFundsAvailable];
}

- (void)hideSelectFromAndToButtonsIfAppropriate
{
    if ([WalletManager.sharedInstance.wallet getActiveAccountsCount:self.assetType] + [[WalletManager.sharedInstance.wallet activeLegacyAddresses:self.assetType] count] == 1) {
        [selectFromButton setHidden:YES];
        if ([WalletManager.sharedInstance.wallet addressBook].count == 0) {
            [addressBookButton setHidden:YES];
        } else {
            [addressBookButton setHidden:NO];
        }
    }
    else {
        [selectFromButton setHidden:NO];
        [addressBookButton setHidden:NO];
    }
}

- (void)populateFieldsFromURLHandlerIfAvailable
{
    if (self.addressFromURLHandler && toField != nil) {
        self.sendToAddress = true;
        self.toAddress = self.addressFromURLHandler;
        DLog(@"toAddress: %@", self.toAddress);
        
        toField.text = [WalletManager.sharedInstance.wallet labelForLegacyAddress:self.toAddress assetType:self.assetType];
        self.addressFromURLHandler = nil;
        
        amountInSatoshi = self.amountFromURLHandler;
        [self performSelector:@selector(doCurrencyConversion) withObject:nil afterDelay:0.1f];
        self.amountFromURLHandler = 0;
    }
}

- (void)reloadFromAndToFields
{
    [self reloadFromField];
    [self reloadToField];
}

- (void)reloadFromField
{
    if (self.sendFromAddress) {
        if (self.fromAddress.length == 0) {
            selectAddressTextField.text = BC_STRING_ANY_ADDRESS;
            availableAmount = [WalletManager.sharedInstance.wallet getTotalBalanceForSpendableActiveLegacyAddresses];
        }
        else {
            selectAddressTextField.text = [WalletManager.sharedInstance.wallet labelForLegacyAddress:self.fromAddress assetType:self.assetType];
            availableAmount = [[WalletManager.sharedInstance.wallet getLegacyAddressBalance:self.fromAddress assetType:self.assetType] longLongValue];
        }
    }
    else {
        selectAddressTextField.text = [WalletManager.sharedInstance.wallet getLabelForAccount:self.fromAccount assetType:self.assetType];
        availableAmount = [[WalletManager.sharedInstance.wallet getBalanceForAccount:self.fromAccount assetType:self.assetType] longLongValue];
    }
}

- (void)reloadToField
{
    if (self.sendToAddress) {
        toField.text = [WalletManager.sharedInstance.wallet labelForLegacyAddress:self.toAddress assetType:self.assetType];
        if ([WalletManager.sharedInstance.wallet isValidAddress:self.toAddress assetType:self.assetType]) {
            [self selectToAddress:self.toAddress];
        } else {
            toField.text = @"";
            self.toAddress = @"";
        }
    }
    else {
        toField.text = [WalletManager.sharedInstance.wallet getLabelForAccount:self.toAccount assetType:self.assetType];
        [self selectToAccount:self.toAccount];
    }
}

- (void)reloadLocalAndBtcSymbolsFromLatestResponse
{
    if (WalletManager.sharedInstance.latestMultiAddressResponse.symbol_local && WalletManager.sharedInstance.latestMultiAddressResponse.symbol_btc) {
        fiatLabel.text = WalletManager.sharedInstance.latestMultiAddressResponse.symbol_local.code;
        btcLabel.text = self.assetType == LegacyAssetTypeBitcoin ? WalletManager.sharedInstance.latestMultiAddressResponse.symbol_btc.symbol : CURRENCY_SYMBOL_BCH;
    }
    
    if (BlockchainSettings.sharedAppInstance.symbolLocal && WalletManager.sharedInstance.latestMultiAddressResponse.symbol_local && WalletManager.sharedInstance.latestMultiAddressResponse.symbol_local.conversion > 0) {
        displayingLocalSymbol = TRUE;
        displayingLocalSymbolSend = TRUE;
    } else if (WalletManager.sharedInstance.latestMultiAddressResponse.symbol_btc) {
        displayingLocalSymbol = FALSE;
        displayingLocalSymbolSend = FALSE;
    }
}

#pragma mark - Exchange address button

- (void)exchangeAddressButtonPressed {
    switch (self.addressSource) {
        case DestinationAddressSourceExchange:
            [self.exchangeAddressButton setImage:[UIImage imageNamed:@"exchange-icon-small"] forState:UIControlStateNormal];
            self.addressSource = DestinationAddressSourcePaste;
            self.toAddress = nil;
            toField.hidden = false;
            toField.text = nil;
            destinationAddressIndicatorLabel.hidden = true;
            break;
        default: // Any other state (doesn't matter which)
            [self reportExchangeButtonClick];
            /// The user tapped the Exchange button to send funds to the Exchange.
            /// We must confirm that 2FA is enabled otherwise we will not have a destination address
            if (self.exchangeAddressViewModel != nil && self.exchangeAddressViewModel.legacyAssetType == self.assetType) {
                if (self.exchangeAddressViewModel.address != nil) {
                    [self.exchangeAddressButton setImage:[UIImage imageNamed:@"cancel_icon"] forState:UIControlStateNormal];
                    self.addressSource = DestinationAddressSourceExchange;
                    toField.hidden = true;
                    [self selectToAddress:self.exchangeAddressViewModel.address];
                    destinationAddressIndicatorLabel.hidden = false;
                } else {
                    [AlertViewPresenter.sharedInstance standardErrorWithMessage:[LocalizationConstantsObjcBridge twoFactorExchangeDisabled] title:BC_STRING_ERROR in:self handler:nil];
                }
            }
            break;
    }
}

#pragma mark - Payment

- (IBAction)reallyDoPayment:(id)sender
{
    if (self.isBitpayPayPro) {
        
        NSString *bitpayInvoiceID = @"";
        NSString *entry = toField.text;
        NSURL *bitpayURLCandidate = [NSURL URLWithString:entry];
        if (bitpayURLCandidate != nil) {
            if ([self isBitpayURL:bitpayURLCandidate])
            {
                bitpayInvoiceID = [self invoiceIDFromBitPayURL:bitpayURLCandidate];
            }
        }
        
        if (bitpayInvoiceID.length == 0) {
            DLog(@"Expected an invoiceID.");
            [self handleSigningPaymentError:BC_STRING_ERROR];
            return;
        }
        
        __weak typeof(self) weakSelf = self;
        if (self.assetType == LegacyAssetTypeBitcoinCash) {
            [WalletManager.sharedInstance.wallet signBitcoinCashPaymentWithSecondPassword:nil successBlock:^(NSString * _Nonnull transactionHex) {
                NSArray *hexAndWeight = [transactionHex componentsSeparatedByString:@","];
                NSString *hex = [hexAndWeight firstObject];
                NSString *weight = [hexAndWeight lastObject];
                [weakSelf verifyAndPostBitpayWithInvoiceID:bitpayInvoiceID transactionHex:hex transactionSize:weight];
            } error:^(NSString * _Nonnull errorMessage) {
                [weakSelf handleSigningPaymentError:errorMessage];
            }];
        }
        if (self.assetType == LegacyAssetTypeBitcoin) {
            [WalletManager.sharedInstance.wallet signBitcoinPaymentWithSecondPassword:nil successBlock:^(NSString * _Nonnull transactionHex) {
                NSArray *hexAndWeight = [transactionHex componentsSeparatedByString:@","];
                NSString *hex = [hexAndWeight firstObject];
                NSString *weight = [hexAndWeight lastObject];
                [weakSelf verifyAndPostBitpayWithInvoiceID:bitpayInvoiceID transactionHex:hex transactionSize:weight];
            } error:^(NSString * _Nonnull errorMessage) {
                [weakSelf handleSigningPaymentError:errorMessage];
            }];
        }
        return;
    }
    if (self.sendFromAddress && [WalletManager.sharedInstance.wallet isWatchOnlyLegacyAddress:self.fromAddress]) {
        [self alertUserForSpendingFromWatchOnlyAddress];
        return;
    }
    [self sendPaymentWithListener];
}

- (void)handleSigningPaymentError:(NSString *)errorMessage
{
    DLog(@"Send error: %@", errorMessage);
    [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:errorMessage title:BC_STRING_ERROR in:self handler: nil];
    
    [self->sendProgressActivityIndicator stopAnimating];
    
    [self enablePaymentButtons];
    
    [[ModalPresenter sharedInstance] closeModalWithTransition:kCATransitionFade];
    
    [self reload];
    
    [WalletManager.sharedInstance.wallet getHistory];
}

- (void)verifyAndPostBitpayWithInvoiceID:(NSString *)invoiceID transactionHex:(NSString *)transactionHex transactionSize:(NSString *)size
{
    [self.bitpayService verifyAndPostSignedTransactionWithInvoiceID:invoiceID assetType:self.assetType transactionHex:transactionHex transactionSize:size completion:^(NSString * _Nullable memo, NSError * _Nullable error) {
        /// The transaction was successful
        if (memo != nil) {
            [WalletActionEventBus.sharedInstance publishObjWithAction:WalletActionSendCrypto extras:nil];
            UIAlertController *paymentSentAlert = [UIAlertController alertControllerWithTitle:[LocalizationConstantsObjcBridge success] message:BC_STRING_PAYMENT_SENT preferredStyle:UIAlertControllerStyleAlert];
            [paymentSentAlert addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [[AppReviewPrompt sharedInstance] showIfNeeded];
            }]];
            
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:paymentSentAlert animated:YES completion:nil];
            
            [self->sendProgressActivityIndicator stopAnimating];
            
            [self enablePaymentButtons];
            
            // Fields are automatically reset by reload, called by MyWallet.wallet.getHistory() after a utx websocket message is received. However, we cannot rely on the websocket 100% of the time.
            if (self.assetType == LegacyAssetTypeBitcoin) {
                [WalletManager.sharedInstance.wallet performSelector:@selector(getHistoryIfNoTransactionMessage) withObject:nil afterDelay:DELAY_GET_HISTORY_BACKUP];
            } else {
                [WalletManager.sharedInstance.wallet performSelector:@selector(getBitcoinCashHistoryIfNoTransactionMessage) withObject:nil afterDelay:DELAY_GET_HISTORY_BACKUP];
            }
            
            // Close transaction modal, go to transactions view, scroll to top and animate new transaction
            [self.bitpayTimer invalidate];
            
            [[ModalPresenter sharedInstance] closeModalWithTransition:kCATransitionFade];
            TabControllerManager *tabControllerManager = [AppCoordinator sharedInstance].tabControllerManager;
            [tabControllerManager.transactionsBitcoinViewController didReceiveTransactionMessage];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [tabControllerManager transactionsClicked:nil];
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [tabControllerManager.transactionsBitcoinViewController.tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
            });
            
            [self reload];
        }
        /// The transaction was not successful
        if (error != nil) {
            DLog(@"Send error: %@", error);
            [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:error.localizedDescription title:BC_STRING_ERROR in:self handler: nil];
            
            [self->sendProgressActivityIndicator stopAnimating];
            
            [self enablePaymentButtons];
            
            [[ModalPresenter sharedInstance] closeModalWithTransition:kCATransitionFade];
            
            [self reload];
            
            [WalletManager.sharedInstance.wallet getHistory];
        }
    }];
}

- (void)getInfoForTransferAllFundsToDefaultAccount
{
    [[LoadingViewPresenter sharedInstance] showWith:BC_STRING_TRANSFER_ALL_PREPARING_TRANSFER];
    
    [WalletManager.sharedInstance.wallet getInfoForTransferAllFundsToAccount];
}

- (void)transferFundsToDefaultAccountFromAddress:(NSString *)address
{
    [self didSelectFromAddress:address];
    
    [self selectToAccount:[WalletManager.sharedInstance.wallet getDefaultAccountIndexForAssetType:self.assetType]];
    
    [WalletManager.sharedInstance.wallet transferFundsToDefaultAccountFromAddress:address];
}

- (void)sendFromWatchOnlyAddress
{
    [self sendPaymentWithListener];
}

- (void)sendPaymentWithListener
{
    [self disablePaymentButtons];
    
    [sendProgressActivityIndicator startAnimating];
    
    sendProgressModalText.text = BC_STRING_SENDING_TRANSACTION;

    [[ModalPresenter sharedInstance] showModalWithContent:sendProgressModal closeType:ModalCloseTypeNone showHeader:true headerText:BC_STRING_SENDING_TRANSACTION onDismiss:nil onResume:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        TransactionProgressListeners *listener = [[TransactionProgressListeners alloc] init];
         
         listener.on_start = ^() {
         };
         
         listener.on_begin_signing = ^(NSString* intput) {
             self->sendProgressModalText.text = BC_STRING_SIGNING_INPUTS;
         };
         
         listener.on_sign_progress = ^(int input) {
             DLog(@"Signing input: %d", input);
             self->sendProgressModalText.text = [NSString stringWithFormat:BC_STRING_SIGNING_INPUT, input];
         };
         
         listener.on_finish_signing = ^(NSString* intput) {
             self->sendProgressModalText.text = BC_STRING_FINISHED_SIGNING_INPUTS;
         };
         
         listener.on_success = ^(NSString*secondPassword, NSString *transactionHash, NSString *transactionHex) {
             DLog(@"SendViewController: on_success");
             [WalletActionEventBus.sharedInstance publishObjWithAction:WalletActionSendCrypto extras:nil];

             [self reportSendSummaryConfirmSuccess];
             
             UIAlertController *paymentSentAlert = [UIAlertController alertControllerWithTitle:[LocalizationConstantsObjcBridge success] message:BC_STRING_PAYMENT_SENT preferredStyle:UIAlertControllerStyleAlert];
             [paymentSentAlert addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                 [[AppReviewPrompt sharedInstance] showIfNeeded];
             }]];
             
             [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:paymentSentAlert animated:YES completion:nil];
             
             [self->sendProgressActivityIndicator stopAnimating];
             
             [self enablePaymentButtons];
             
             // Fields are automatically reset by reload, called by MyWallet.wallet.getHistory() after a utx websocket message is received. However, we cannot rely on the websocket 100% of the time.
             if (self.assetType == LegacyAssetTypeBitcoin) {
                 [WalletManager.sharedInstance.wallet performSelector:@selector(getHistoryIfNoTransactionMessage) withObject:nil afterDelay:DELAY_GET_HISTORY_BACKUP];
             } else {
                 [WalletManager.sharedInstance.wallet performSelector:@selector(getBitcoinCashHistoryIfNoTransactionMessage) withObject:nil afterDelay:DELAY_GET_HISTORY_BACKUP];
             }
             
             // Close transaction modal, go to transactions view, scroll to top and animate new transaction
             if(self.isBitpayPayPro) {
                 [self.bitpayTimer invalidate];
             }
             [[ModalPresenter sharedInstance] closeModalWithTransition:kCATransitionFade];
             TabControllerManager *tabControllerManager = [AppCoordinator sharedInstance].tabControllerManager;
             [tabControllerManager.transactionsBitcoinViewController didReceiveTransactionMessage];
             dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                 [tabControllerManager transactionsClicked:nil];
             });
             dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                 [tabControllerManager.transactionsBitcoinViewController.tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
             });
             
             if (self.noteToSet) {
                 [WalletManager.sharedInstance.wallet saveNote:self.noteToSet forTransaction:transactionHash];
             }
             
             [self reload];
         };
         
         listener.on_error = ^(NSString* error, NSString* secondPassword) {
             DLog(@"Send error: %@", error);
                          
             [self reportSendSummaryConfirmFailure];
             
             if ([error isEqualToString:ERROR_UNDEFINED]) {
                 [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:BC_STRING_SEND_ERROR_NO_INTERNET_CONNECTION title:BC_STRING_ERROR in:self handler: nil];
             } else if ([error isEqualToString:ERROR_FEE_TOO_LOW]) {
                 [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:BC_STRING_SEND_ERROR_FEE_TOO_LOW title:BC_STRING_ERROR in:self handler: nil];
             } else if ([error isEqualToString:ERROR_FAILED_NETWORK_REQUEST]) {
                 [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:[LocalizationConstantsObjcBridge requestFailedCheckConnection] title:BC_STRING_ERROR in:self handler: nil];
             } else if (error && error.length != 0)  {
                 [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:error title:BC_STRING_ERROR in:self handler: nil];
             }
             
             [self->sendProgressActivityIndicator stopAnimating];
             
             [self enablePaymentButtons];
             
             [[ModalPresenter sharedInstance] closeModalWithTransition:kCATransitionFade];
             
             [self reload];
             
             [WalletManager.sharedInstance.wallet getHistory];
         };
         
         NSString *amountString;
         amountString = [[NSNumber numberWithLongLong:amountInSatoshi] stringValue];
         
         DLog(@"Sending uint64_t %llu Satoshi (String value: %@)", amountInSatoshi, amountString);
         
         // Different ways of sending (from/to address or account
         if (self.sendFromAddress && self.sendToAddress) {
             DLog(@"From: %@", self.fromAddress);
             DLog(@"To: %@", self.toAddress);
         }
         else if (self.sendFromAddress && !self.sendToAddress) {
             DLog(@"From: %@", self.fromAddress);
             DLog(@"To account: %d", self.toAccount);
         }
         else if (!self.sendFromAddress && self.sendToAddress) {
             DLog(@"From account: %d", self.fromAccount);
             DLog(@"To: %@", self.toAddress);
         }
         else if (!self.sendFromAddress && !self.sendToAddress) {
             DLog(@"From account: %d", self.fromAccount);
             DLog(@"To account: %d", self.toAccount);
         }
         
         WalletManager.sharedInstance.wallet.didReceiveMessageForLastTransaction = NO;
         
         [self sendPaymentWithListener:listener secondPassword:nil];
    });
}

- (void)transferAllFundsToDefaultAccount
{
    __weak SendBitcoinViewController *weakSelf = self;
    
    self.transferAllPaymentBuilder.on_before_send = ^() {
        
        SendBitcoinViewController *strongSelf = weakSelf;
        
        [weakSelf hideKeyboard];
        
        [weakSelf disablePaymentButtons];
        
        [strongSelf->sendProgressActivityIndicator startAnimating];
        
        if (weakSelf.transferAllPaymentBuilder.transferAllAddressesInitialCount - [weakSelf.transferAllPaymentBuilder.transferAllAddressesToTransfer count] <= weakSelf.transferAllPaymentBuilder.transferAllAddressesInitialCount) {
            strongSelf->sendProgressModalText.text = [NSString stringWithFormat:BC_STRING_TRANSFER_ALL_FROM_ADDRESS_ARGUMENT_ARGUMENT, weakSelf.transferAllPaymentBuilder.transferAllAddressesInitialCount - [weakSelf.transferAllPaymentBuilder.transferAllAddressesToTransfer count] + 1, weakSelf.transferAllPaymentBuilder.transferAllAddressesInitialCount];
        }

        [[ModalPresenter sharedInstance] showModalWithContent:strongSelf->sendProgressModal closeType:ModalCloseTypeNone showHeader:true headerText:BC_STRING_SENDING_TRANSACTION onDismiss:^{
            [LoadingViewPresenter.sharedInstance setIsEnabled:TRUE];
        } onResume:^{
            [LoadingViewPresenter.sharedInstance setIsEnabled:TRUE];
        }];
        
        [UIView animateWithDuration:0.3f animations:^{
            UIButton *cancelButton = strongSelf->sendProgressCancelButton;
            strongSelf->sendProgressCancelButton.frame = CGRectMake(0, self.view.frame.size.height + DEFAULT_FOOTER_HEIGHT - cancelButton.frame.size.height, cancelButton.frame.size.width, cancelButton.frame.size.height);
        }];
        
        // Once the modal
        [LoadingViewPresenter.sharedInstance setIsEnabled:FALSE];
        weakSelf.isSending = YES;
    };
    
    self.transferAllPaymentBuilder.on_prepare_next_transfer = ^(NSArray *transferAllAddressesToTransfer) {
        weakSelf.fromAddress = transferAllAddressesToTransfer[0];
    };
    
    self.transferAllPaymentBuilder.on_success = ^(NSString *secondPassword) {
        
    };
    
    self.transferAllPaymentBuilder.on_error = ^(NSString *error, NSString *secondPassword) {
        
        SendBitcoinViewController *strongSelf = weakSelf;

        [[ModalPresenter sharedInstance] closeAllModals];

        [strongSelf->sendProgressActivityIndicator stopAnimating];
        
        [weakSelf enablePaymentButtons];
        
        [weakSelf reload];
    };

    [self.transferAllPaymentBuilder transferAllFundsToAccountWithSecondPassword:nil];
}

- (void)didFinishTransferFunds:(NSString *)summary
{
    NSString *message = [self.transferAllPaymentBuilder.transferAllAddressesTransferred count] > 0 ? [NSString stringWithFormat:@"%@\n\n%@", summary, BC_STRING_PAYMENT_ASK_TO_ARCHIVE_TRANSFERRED_ADDRESSES] : summary;
    
    UIAlertController *alertForPaymentsSent = [UIAlertController alertControllerWithTitle:BC_STRING_PAYMENTS_SENT message:message preferredStyle:UIAlertControllerStyleAlert];
    
    if ([self.transferAllPaymentBuilder.transferAllAddressesTransferred count] > 0) {
        [alertForPaymentsSent addAction:[UIAlertAction actionWithTitle:BC_STRING_ARCHIVE style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self archiveTransferredAddresses];
        }]];
        [alertForPaymentsSent addAction:[UIAlertAction actionWithTitle:BC_STRING_NOT_NOW style:UIAlertActionStyleCancel handler:nil]];
    } else {
        [alertForPaymentsSent addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:nil]];
    }

    TabControllerManager *tabControllerManager = [AppCoordinator sharedInstance].tabControllerManager;
    [tabControllerManager.tabViewController presentViewController:alertForPaymentsSent animated:YES completion:nil];
    
    [sendProgressActivityIndicator stopAnimating];
    
    [self enablePaymentButtons];
    
    // Fields are automatically reset by reload, called by MyWallet.wallet.getHistory() after a utx websocket message is received. However, we cannot rely on the websocket 100% of the time.
    if (self.assetType == LegacyAssetTypeBitcoin) {
        [WalletManager.sharedInstance.wallet performSelector:@selector(getHistoryIfNoTransactionMessage) withObject:nil afterDelay:DELAY_GET_HISTORY_BACKUP];
    } else {
        [WalletManager.sharedInstance.wallet performSelector:@selector(getBitcoinCashHistoryIfNoTransactionMessage) withObject:nil afterDelay:DELAY_GET_HISTORY_BACKUP];
    }
    
    // Close transaction modal, go to transactions view, scroll to top and animate new transaction
    [[ModalPresenter sharedInstance] closeAllModals];
    [tabControllerManager.transactionsBitcoinViewController didReceiveTransactionMessage];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [tabControllerManager transactionsClicked:nil];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [tabControllerManager.transactionsBitcoinViewController.tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
    });
    
    [self reload];
}

- (void)sendDuringTransferAll:(NSString *)secondPassword
{
    [self.transferAllPaymentBuilder transferAllFundsToAccountWithSecondPassword:secondPassword];
}

- (void)didErrorDuringTransferAll:(NSString *)error secondPassword:(NSString *)secondPassword
{
    [[ModalPresenter sharedInstance] closeAllModals];
    [self reload];
    
    [self showErrorBeforeSending:error];
}

- (void)showSummary
{
    [self showSummaryForTransferAllWithCustomFromLabel:nil];
}

- (void)showSummaryForTransferAllWithCustomFromLabel:(NSString *)customFromLabel
{
    [self hideKeyboard];
    
    // Timeout so the keyboard is fully dismised - otherwise the second password modal keyboard shows the send screen kebyoard accessory
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        if ([self transferAllMode]) {
            [[ModalPresenter sharedInstance].modalView.backButton addTarget:self action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];
        }
        
        uint64_t amountTotal = amountInSatoshi + self.feeFromTransactionProposal + self.dust;
        uint64_t feeTotal = self.dust + self.feeFromTransactionProposal;
        
        NSString *fromAddressLabel = self.sendFromAddress ? [WalletManager.sharedInstance.wallet labelForLegacyAddress:self.fromAddress assetType:self.assetType] : [WalletManager.sharedInstance.wallet getLabelForAccount:self.fromAccount assetType:self.assetType];
        
        NSString *fromAddressString = self.sendFromAddress ? self.fromAddress : @"";
        
        if ([self.fromAddress isEqualToString:@""] && self.sendFromAddress) {
            fromAddressString = BC_STRING_ANY_ADDRESS;
        }
        
        // When a legacy wallet has no label, labelForLegacyAddress returns the address, so remove the string
        if ([fromAddressLabel isEqualToString:fromAddressString]) {
            fromAddressLabel = @"";
        }
        
        if (customFromLabel) {
            fromAddressString = customFromLabel;
        }
        
        NSString *toAddressLabel = self.sendToAddress ? [WalletManager.sharedInstance.wallet labelForLegacyAddress:self.toAddress assetType:self.assetType] : [WalletManager.sharedInstance.wallet getLabelForAccount:self.toAccount assetType:self.assetType];
        
        BOOL shouldRemoveToAddress = NO;
        
        NSString *toAddressString = self.sendToAddress ? (shouldRemoveToAddress ? @"" : self.toAddress) : @"";
        
        // When a legacy wallet has no label, labelForLegacyAddress returns the address, so remove the string
        if ([toAddressLabel isEqualToString:toAddressString]) {
            toAddressLabel = @"";
        }
        
        NSString *from = fromAddressLabel.length == 0 ? fromAddressString : fromAddressLabel;
        NSString *to = toAddressLabel.length == 0 ? toAddressString : toAddressLabel;
        
        BOOL surgePresent = self.surgeIsOccurring || [[NSUserDefaults standardUserDefaults] boolForKey:USER_DEFAULTS_KEY_DEBUG_SIMULATE_SURGE];
        
        BCConfirmPaymentViewModel *confirmPaymentViewModel;
        
        NSString *displayDestinationAddress;
        NSString *symbol;
        switch (self.addressSource) {
            case DestinationAddressSourceExchange:
                symbol = [AssetTypeLegacyHelper symbolFor: self.assetType];
                displayDestinationAddress = [NSString stringWithFormat:[LocalizationConstantsObjcBridge sendAssetExchangeDestination], symbol];
                break;
            case DestinationAddressSourceBitPay:
                displayDestinationAddress = [NSString stringWithFormat: @"BitPay[%@]", self.bitpayMerchant];
                break;
            default:
                displayDestinationAddress = to;
        }
        
        if (self.assetType == LegacyAssetTypeBitcoinCash) {
            confirmPaymentViewModel = [[BCConfirmPaymentViewModel alloc] initWithFrom:from
                                                            destinationDisplayAddress:displayDestinationAddress
                                                                destinationRawAddress:to
                                                                            bchAmount:amountInSatoshi
                                                                                  fee:feeTotal
                                                                                total:amountTotal
                                                                                surge:surgePresent];
        } else {
            confirmPaymentViewModel = [[BCConfirmPaymentViewModel alloc] initWithFrom:from
                                                            destinationDisplayAddress:displayDestinationAddress
                                                                destinationRawAddress:to
                                                                               amount:amountInSatoshi
                                                                                  fee:feeTotal
                                                                                total:amountTotal
                                                                                surge:surgePresent];
        }
        
        self.confirmPaymentView = [[BCConfirmPaymentView alloc] initWithFrame:self.view.frame
                                                                     viewModel:confirmPaymentViewModel
                                                              sendButtonFrame:self->continuePaymentButton.frame];
        
        self.confirmPaymentView.confirmDelegate = self;
        
        if (customFromLabel) {
            [self.confirmPaymentView.reallyDoPaymentButton addTarget:self action:@selector(transferAllFundsToDefaultAccount) forControlEvents:UIControlEventTouchUpInside];
        } else {
            [self.confirmPaymentView.reallyDoPaymentButton addTarget:self action:@selector(reallyDoPayment:) forControlEvents:UIControlEventTouchUpInside];
        }
        
        [self.confirmPaymentView.reallyDoPaymentButton addTarget:self action:@selector(reportSendSummaryConfirmClick) forControlEvents:UIControlEventTouchUpInside];

        [[ModalPresenter sharedInstance] showModalWithContent:self.confirmPaymentView closeType:ModalCloseTypeBack showHeader:true headerText:BC_STRING_CONFIRM_PAYMENT onDismiss:^{
            [self enablePaymentButtons];
        } onResume:nil];
        
        NSDecimalNumber *last = [NSDecimalNumber decimalNumberWithDecimal:[[NSDecimalNumber numberWithDouble:[[WalletManager.sharedInstance.wallet.btcRates objectForKey:DICTIONARY_KEY_USD][DICTIONARY_KEY_LAST] doubleValue]] decimalValue]];
        NSDecimalNumber *conversionToUSD = [[NSDecimalNumber decimalNumberWithDecimal:[[NSDecimalNumber numberWithDouble:SATOSHI] decimalValue]] decimalNumberByDividingBy:last];
        NSDecimalNumber *feeConvertedToUSD = [(NSDecimalNumber *)[NSDecimalNumber numberWithLongLong:feeTotal] decimalNumberByDividingBy:conversionToUSD];
        
        NSDecimalNumber *feeRatio = [[NSDecimalNumber decimalNumberWithDecimal:[[NSDecimalNumber numberWithLongLong:feeTotal] decimalValue] ] decimalNumberByDividingBy:(NSDecimalNumber *)[NSDecimalNumber numberWithLongLong:amountTotal]];
        NSDecimalNumber *normalFeeRatio = [NSDecimalNumber decimalNumberWithDecimal:[ONE_PERCENT_DECIMAL decimalValue]];
        
        if ([feeConvertedToUSD compare:[NSDecimalNumber decimalNumberWithDecimal:[FIFTY_CENTS_DECIMAL decimalValue]]] == NSOrderedDescending && self.txSize > TX_SIZE_ONE_KILOBYTE && [feeRatio compare:normalFeeRatio] == NSOrderedDescending) {
            UIAlertController *highFeeAlert = [UIAlertController alertControllerWithTitle:BC_STRING_HIGH_FEE_WARNING_TITLE message:BC_STRING_HIGH_FEE_WARNING_MESSAGE preferredStyle:UIAlertControllerStyleAlert];
            [highFeeAlert addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:nil]];
            [self.view.window.rootViewController presentViewController:highFeeAlert animated:YES completion:nil];
        }
    });
}

- (void)handleZeroSpendableAmount
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BC_STRING_NO_AVAILABLE_FUNDS message:BC_STRING_PLEASE_SELECT_DIFFERENT_ADDRESS preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:nil]];
    [[NSNotificationCenter defaultCenter] addObserver:alert selector:@selector(autoDismiss) name:ConstantsObjcBridge.notificationKeyReloadToDismissViews object:nil];
    TabControllerManager *tabControllerManager = [AppCoordinator sharedInstance].tabControllerManager;
    [tabControllerManager.tabViewController presentViewController:alert animated:YES completion:nil];
    [self enablePaymentButtons];
}

- (IBAction)sendProgressCancelButtonClicked:(UIButton *)sender
{
    sendProgressModalText.text = BC_STRING_CANCELLING;
    self.transferAllPaymentBuilder.userCancelledNext = YES;
    [self performSelector:@selector(cancelAndReloadIfTransferFails) withObject:nil afterDelay:10.0];
}

- (void)cancelAndReloadIfTransferFails
{
    if (self.isSending && [sendProgressModalText.text isEqualToString:BC_STRING_CANCELLING]) {
        [self reload];
        [[ModalPresenter sharedInstance] closeAllModals];
    }
}

#pragma mark - UI Helpers

- (void)doCurrencyConversion
{
    [self doCurrencyConversionAfterMultiAddress:NO];
}

- (void)doCurrencyConversionAfterMultiAddress
{
    [self doCurrencyConversionAfterMultiAddress:YES];
}

- (void)doCurrencyConversionAfterMultiAddress:(BOOL)afterMultiAddress
{
    // If the amount entered exceeds amount available, change the color of the amount text
    if (amountInSatoshi > availableAmount || amountInSatoshi > BTC_LIMIT_IN_SATOSHI) {
        [self highlightInvalidAmounts];
        [self disablePaymentButtons];
    }
    else {
        [self removeHighlightFromAmounts];
        [self enablePaymentButtons];
        if (!afterMultiAddress) {
            [WalletManager.sharedInstance.wallet changePaymentAmount:[NSNumber numberWithLongLong:amountInSatoshi] assetType:self.assetType];
            [self updateSatoshiPerByteWithUpdateType:FeeUpdateTypeNoAction];
        }
    }
    
    if ([btcAmountField isFirstResponder]) {
        fiatAmountField.text = [self formatAmount:amountInSatoshi localCurrency:YES];
    }
    else if ([fiatAmountField isFirstResponder]) {
        btcAmountField.text = [self formatAmount:amountInSatoshi localCurrency:NO];
    }
    else {
        fiatAmountField.text = [self formatAmount:amountInSatoshi localCurrency:YES];
        btcAmountField.text = [self formatAmount:amountInSatoshi localCurrency:NO];
    }
    
    [self updateFundsAvailable];
}

- (void)highlightInvalidAmounts
{
    btcAmountField.textColor = UIColor.error;
    fiatAmountField.textColor = UIColor.error;
}

- (void)removeHighlightFromAmounts
{
    btcAmountField.textColor = UIColor.gray5;
    fiatAmountField.textColor = UIColor.gray5;
}

- (void)handleTimerTick:(NSTimer *)timer
{
    if (self.bitpayExpiration == nil) {
        [timer invalidate];
        [self cleanUpBitPayPayment];
        return;
    }
    NSTimeInterval interval = [self.bitpayExpiration timeIntervalSinceNow];
    int secondsInAnHour = 3600;
    int hours = interval / secondsInAnHour;
    int minutesInAnHour = 60;
    int minutes = (interval - hours * secondsInAnHour) / minutesInAnHour;
    int secondsInAMinute = 60;
    int seconds = interval - hours * secondsInAnHour - minutes * secondsInAMinute;
    
    NSString *hoursString = [NSString stringWithFormat:@"%02d", hours];
    NSString *minutesString = minutes > 9 ? [NSString stringWithFormat:@"%02d", minutes] : [NSString stringWithFormat:@"%d", minutes];
    NSString *secondsString = [NSString stringWithFormat:@"%02d", seconds];
    NSString *secondsFormattedString = seconds < 10 ? [[NSNumberFormatter localFormattedString:@"0"] stringByAppendingString:[NSNumberFormatter localFormattedString:secondsString]] : [NSNumberFormatter localFormattedString:secondsString];
    NSString *timeString = hours > 0 ? [NSString stringWithFormat:@"%@:%@:%@", [NSNumberFormatter localFormattedString:hoursString], [NSNumberFormatter localFormattedString:minutesString], secondsFormattedString] : [NSString stringWithFormat:@"%@:%@", [NSNumberFormatter localFormattedString:minutesString], secondsFormattedString];
    
    self.bitpayTimeRemainingText.text = [NSString stringWithFormat:BC_STRING_BITPAY_TIME_REMAINING, timeString];
    if (hours == 0 && minutes < 1) {
        self.bitpayTimeRemainingText.textColor = UIColor.error;
    } else if (hours == 0 && minutes < 5) {
        self.bitpayTimeRemainingText.textColor = UIColor.orangeColor;
    }
    
    if (hours + minutes <= 0 && seconds <= 2) {
        [self.analyticsRecorder recordWithEvent:[[BitpayPaymentExpired alloc] init]];
        [timer invalidate];
        [self showBitPayExpiredAlert];
    }
}

- (void)showBitPayExpiredAlert
{
    UIAlertController *expiredAlert = [UIAlertController alertControllerWithTitle:BC_STRING_BITPAY_INVOICE_EXPIRED_TITLE message:BC_STRING_BITPAY_INVOICE_EXPIRED_MESSAGE preferredStyle:UIAlertControllerStyleAlert];
    [expiredAlert addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self.navigationController popViewControllerAnimated:YES];
        [self reload];
    }]];
    [self presentViewController:expiredAlert animated:YES completion:nil];
    [self cleanUpBitPayPayment];
}

- (void)cleanUpBitPayPayment
{
    [self clearToAddressAndAmountFields];
    [self enableInputs];
    [self.bitpayTimer invalidate];
    self.isBitpayPayPro = NO;
    [self updateFundsAvailable];
    self.feeType = FeeTypeRegular;
    [self updateFeeLabels];
    self.bitpayLabel.hidden = YES;
    self.bitpayLogo.hidden = YES;
    self.bitpayTimeRemainingText.hidden = YES;
    self.lineBelowBitpayLabel.hidden = YES;
}

- (void)enableInputs
{
    btcAmountField.enabled = YES;
    fiatAmountField.enabled = YES;
    toField.enabled = YES;
    feeField.enabled = YES;
    fundsAvailableButton.enabled = YES;
    [self->feeTappableView setUserInteractionEnabled:YES];
    fundsAvailableButton.hidden = NO;
    addressBookButton.enabled = YES;
    feeOptionsButton.enabled = YES;
}

- (void)disableInputs
{
    btcAmountField.enabled = NO;
    fiatAmountField.enabled = NO;
    toField.enabled = NO;
    feeField.enabled = NO;
    fundsAvailableButton.enabled = NO;
    [self->feeTappableView setUserInteractionEnabled:NO];
    fundsAvailableButton.hidden = true;
    addressBookButton.enabled = NO;
    feeOptionsButton.enabled = NO;
}

- (void)disablePaymentButtons
{
    continuePaymentButton.enabled = NO;
    [continuePaymentButton setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
    [continuePaymentButton setBackgroundColor:UIColor.keyPadButton];
    
    continuePaymentAccessoryButton.enabled = NO;
    [continuePaymentAccessoryButton setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
    [continuePaymentAccessoryButton setBackgroundColor:UIColor.keyPadButton];
}

- (void)enablePaymentButtons
{
    continuePaymentButton.enabled = YES;
    [continuePaymentButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [continuePaymentButton setBackgroundColor:UIColor.brandSecondary];
    
    [continuePaymentAccessoryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    continuePaymentAccessoryButton.enabled = YES;
    [continuePaymentAccessoryButton setBackgroundColor:UIColor.brandSecondary];
}

- (void)showInsufficientFunds
{
    [self highlightInvalidAmounts];
}

- (void)setAmountStringFromUrlHandler:(NSString*)amountString withToAddress:(NSString*)addressString
{
    self.addressFromURLHandler = addressString;
    
    if ([NSNumberFormatter stringHasBitcoinValue:amountString]) {
        NSDecimalNumber *amountDecimalNumber = [NSDecimalNumber decimalNumberWithString:amountString];
        self.amountFromURLHandler = [[amountDecimalNumber decimalNumberByMultiplyingBy:(NSDecimalNumber *)[NSDecimalNumber numberWithDouble:SATOSHI]] longLongValue];
    } else {
        self.amountFromURLHandler = 0;
    }
    
    self.addressSource = DestinationAddressSourceURI;
}

- (void)hideKeyboardForced
{
    // When backgrounding the app quickly, the input accessory view can remain visible without a first responder, so force the keyboard to appear before dismissing it
    [fiatAmountField becomeFirstResponder];
    [self hideKeyboard];
}

- (void)hideKeyboard
{
    [btcAmountField resignFirstResponder];
    [fiatAmountField resignFirstResponder];
    [toField resignFirstResponder];
    [feeField resignFirstResponder];
    
    [self.view removeGestureRecognizer:self.tapGesture];
    self.tapGesture = nil;
}

- (BOOL)isKeyboardVisible
{
    if ([btcAmountField isFirstResponder] || [fiatAmountField isFirstResponder] || [toField isFirstResponder] || [feeField isFirstResponder]) {
        return YES;
    }
    
    return NO;
}

- (void)showErrorBeforeSending:(NSString *)error
{
    if ([self isKeyboardVisible]) {
        [self hideKeyboard];
        dispatch_after(DELAY_KEYBOARD_DISMISSAL, dispatch_get_main_queue(), ^{
            [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:error title:BC_STRING_ERROR in:self handler:nil];
        });
    } else {
        [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:error title:BC_STRING_ERROR in:self handler:nil];
    }
}

- (void)alertUserForSpendingFromWatchOnlyAddress
{
    UIAlertController *alertForSpendingFromWatchOnly = [UIAlertController alertControllerWithTitle:[LocalizationConstantsObjcBridge privateKeyNeeded] message:[NSString stringWithFormat:BC_STRING_PRIVATE_KEY_NEEDED_MESSAGE_ARGUMENT, self.fromAddress] preferredStyle:UIAlertControllerStyleAlert];
    [alertForSpendingFromWatchOnly addAction:[UIAlertAction actionWithTitle:BC_STRING_CONTINUE style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self scanPrivateKeyToSendFromWatchOnlyAddress];
    }]];
    [alertForSpendingFromWatchOnly addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:nil]];
    TabControllerManager *tabControllerManager = [AppCoordinator sharedInstance].tabControllerManager;
    [tabControllerManager.tabViewController presentViewController:alertForSpendingFromWatchOnly animated:YES completion:nil];
}

- (void)scanPrivateKeyToSendFromWatchOnlyAddress
{
    TabControllerManager *tabControllerManager = [AppCoordinator sharedInstance].tabControllerManager;
    [[KeyImportCoordinator sharedInstance] startWith:self
                                                  in:tabControllerManager.tabViewController
                                           assetType:self.assetType
                                    acceptPublicKeys:NO
                                         loadingText:[LocalizationConstantsObjcBridge loadingProcessingKey]
                                        assetAddress:nil];
}

#pragma mark - LegacyPrivateKeyDelegate

- (void)didFinishScanning:(NSString *)privateKey {
    [WalletManager.sharedInstance.wallet sendFromWatchOnlyAddress:self.fromAddress privateKey:privateKey];
}

- (void)didFinishScanningWithError:(PrivateKeyReaderError)error {
    [[ModalPresenter sharedInstance] closeAllModals];
}

- (void)setupFees
{
    self.feeType = FeeTypeRegular;

    [self arrangeViewsToFeeMode];
    
    [self reloadAfterMultiAddressResponse];
}

- (void)arrangeViewsToFeeMode
{
    [UIView animateWithDuration:ANIMATION_DURATION animations:^{
        
        if (IS_USING_SCREEN_SIZE_4S) {
            [self->lineBelowFromField changeYPosition:38];
            
            [self->toLabel changeYPosition:42];
            [self->toField changeYPosition:38];
            [self->addressBookButton changeYPosition:38];
            [self->lineBelowToField changeYPosition:66];
            
            [self->bottomContainerView changeYPosition:83];
            [self->btcLabel changeYPosition:-11];
            [self->btcAmountField changeYPosition:-15];
            [self->fiatLabel changeYPosition:-11];
            [self->fiatAmountField changeYPosition:-15];
            [self->lineBelowAmountFields changeYPosition:28];
            
            [self->feeTappableView changeYPosition:28];
            [self->feeField changeYPosition:38];
            [self->feeLabel changeYPosition:41];
            [self.feeTypeLabel changeYPosition:37];
            [self.feeDescriptionLabel changeYPosition:51];
            [self.feeAmountLabel changeYPosition:51 - self.feeAmountLabel.frame.size.height/2];
            [self->feeOptionsButton changeYPosition:37];
            [self->lineBelowFeeField changeYPosition:76];
            
            [self->fundsAvailableButton changeYPosition:6];
        }
        
        self->feeLabel.hidden = NO;
        self->feeOptionsButton.hidden = self.assetType == LegacyAssetTypeBitcoinCash;
        self->lineBelowFeeField.hidden = NO;
        
        self.feeAmountLabel.hidden = NO;
        self.feeDescriptionLabel.hidden = NO;
        self.feeTypeLabel.hidden = NO;
    }];
    
    [self updateFeeLabels];
}

- (void)updateSendBalance:(NSNumber *)balance fees:(NSDictionary *)fees
{
    self.fees = fees;
    
    uint64_t newBalance = [balance longLongValue] <= 0 ? 0 : [balance longLongValue];
    
    availableAmount = newBalance;
    
    if (self.feeType != FeeTypeRegular) {
        [self updateSatoshiPerByteWithUpdateType:FeeUpdateTypeNoAction];
    }
    
    if (!self.transferAllPaymentBuilder || self.transferAllPaymentBuilder.userCancelledNext) {
        [self doCurrencyConversionAfterMultiAddress];
    }
}

- (void)updateTransferAllAmount:(NSNumber *)amount fee:(NSNumber *)fee addressesUsed:(NSArray *)addressesUsed
{
    if ([addressesUsed count] == 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showErrorBeforeSending:BC_STRING_NO_ADDRESSES_WITH_SPENDABLE_BALANCE_ABOVE_OR_EQUAL_TO_DUST];
            [[LoadingViewPresenter sharedInstance] hide];
        });
        return;
    }
    
    if ([amount longLongValue] + [fee longLongValue] > [WalletManager.sharedInstance.wallet getTotalBalanceForSpendableActiveLegacyAddresses]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:BC_STRING_SOME_FUNDS_CANNOT_BE_TRANSFERRED_AUTOMATICALLY title:BC_STRING_WARNING_TITLE in:self handler:nil];
            [[LoadingViewPresenter sharedInstance] hide];
        });
    }
    
    self.fromAddress = @"";
    self.sendFromAddress = YES;
    self.sendToAddress = NO;
    self.toAccount = [WalletManager.sharedInstance.wallet getDefaultAccountIndexForAssetType:self.assetType];
    toField.text = [WalletManager.sharedInstance.wallet getLabelForAccount:[WalletManager.sharedInstance.wallet getDefaultAccountIndexForAssetType:self.assetType] assetType:self.assetType];
    
    self.feeFromTransactionProposal = [fee longLongValue];
    amountInSatoshi = [amount longLongValue];
        
    selectAddressTextField.text = [addressesUsed count] == 1 ? [NSString stringWithFormat:BC_STRING_ARGUMENT_ADDRESS, [addressesUsed count]] : [NSString stringWithFormat:BC_STRING_ARGUMENT_ADDRESSES, [addressesUsed count]];
    
    [self disablePaymentButtons];
    
    [self.transferAllPaymentBuilder setupFirstTransferWithAddressesUsed:addressesUsed];
}

- (void)showSummaryForTransferAll
{
    [[LoadingViewPresenter sharedInstance] hide];
    
    [self showSummaryForTransferAllWithCustomFromLabel:selectAddressTextField.text];
    
    [self enablePaymentButtons];
    
    sendProgressCancelButton.hidden = [self.transferAllPaymentBuilder.transferAllAddressesToTransfer count] <= 1;
}

- (BOOL)transferAllMode
{
    return self.transferAllPaymentBuilder && !self.transferAllPaymentBuilder.userCancelledNext;
}

- (void)updateFeeLabels
{
    if (self.feeType == FeeTypeCustom) {
        feeField.hidden = NO;
        [feeTappableView changeXPosition:self.feeAmountLabel.frame.origin.x];
        
        self.feeAmountLabel.hidden = NO;
        self.feeAmountLabel.textColor = UIColor.gray2;

        self.feeDescriptionLabel.hidden = YES;
        
        self.feeTypeLabel.hidden = YES;
    } else {
        feeField.hidden = YES;
        [feeTappableView changeXPosition:0];

        self.feeWarningLabel.hidden = YES;
        [lineBelowFeeField changeYPositionAnimated:[self defaultYPositionForWarningLabel] completion:nil];

        self.feeAmountLabel.hidden = NO;
        self.feeAmountLabel.textColor = UIColor.gray5;
        self.feeAmountLabel.text = nil;
        
        self.feeDescriptionLabel.hidden = NO;
        
        self.feeTypeLabel.hidden = NO;
        
        NSString *typeText;
        NSString *descriptionText;
        
        if (self.feeType == FeeTypeRegular) {
            typeText = BC_STRING_REGULAR;
            descriptionText = BC_STRING_GREATER_THAN_ONE_HOUR;
        } else if (self.feeType == FeeTypePriority) {
            typeText = BC_STRING_PRIORITY;
            descriptionText = BC_STRING_LESS_THAN_ONE_HOUR;
        }
        
        self.feeTypeLabel.text = typeText;
        self.feeDescriptionLabel.text = descriptionText;
    }
}

- (void)updateFeeAmountLabelText:(uint64_t)fee
{
    self.lastDisplayedFee = fee;
    
    if (self.feeType == FeeTypeCustom) {
        NSNumber *regularFee = [self.fees objectForKey:DICTIONARY_KEY_FEE_REGULAR];
        NSNumber *priorityFee = [self.fees objectForKey:DICTIONARY_KEY_FEE_PRIORITY];
        self.feeAmountLabel.text = [NSString stringWithFormat:@"%@: %@, %@: %@", BC_STRING_REGULAR, regularFee, BC_STRING_PRIORITY, priorityFee];
    } else {
        self.feeAmountLabel.text = [NSString stringWithFormat:@"%@ (%@)", [self formatMoney:fee localCurrency:NO], [self formatMoney:fee localCurrency:YES]];
    }
}

- (void)setupFeeWarningLabelFrameSmall
{
    CGFloat warningLabelOriginY = self.feeAmountLabel.frame.origin.y + self.feeAmountLabel.frame.size.height - 4;
    self.feeWarningLabel.frame = CGRectMake(feeField.frame.origin.x, warningLabelOriginY, feeOptionsButton.frame.origin.x - feeField.frame.origin.x, lineBelowFeeField.frame.origin.y - warningLabelOriginY);
}

- (void)setupFeeWarningLabelFrameLarge
{
    CGFloat warningLabelOriginY = self.feeDescriptionLabel.frame.origin.y + self.feeDescriptionLabel.frame.size.height - 4;
    self.feeWarningLabel.frame = CGRectMake(feeField.frame.origin.x, warningLabelOriginY, feeOptionsButton.frame.origin.x - feeField.frame.origin.x, lineBelowFeeField.frame.origin.y - warningLabelOriginY);
}

- (CGFloat)defaultYPositionForWarningLabel
{
    return IS_USING_SCREEN_SIZE_4S ? 76 : 112;
}

- (void)disableToField
{
    CGFloat alpha = 0.0;

    toField.enabled = NO;
    toField.alpha = alpha;
    
    addressBookButton.enabled = NO;
    addressBookButton.alpha = alpha;
}

- (void)enableToField
{
    CGFloat alpha = 1.0;
    
    toField.enabled = YES;
    toField.alpha = alpha;
    
    addressBookButton.enabled = YES;
    addressBookButton.alpha = alpha;
}

- (void)disableAmountViews
{
    CGFloat alpha = 0.5;
    
    btcAmountField.enabled = NO;
    btcAmountField.alpha = alpha;
    
    fiatAmountField.enabled = NO;
    fiatAmountField.alpha = alpha;
    
    fundsAvailableButton.enabled = NO;
    fundsAvailableButton.alpha = alpha;
}

- (void)enableAmountViews
{
    CGFloat alpha = 1.0;

    btcAmountField.enabled = YES;
    btcAmountField.alpha = alpha;
    
    fiatAmountField.enabled = YES;
    fiatAmountField.alpha = alpha;
    
    fundsAvailableButton.enabled = YES;
    fundsAvailableButton.alpha = alpha;
}

- (CGFloat)continuePaymentButtonOriginY
{
    CGFloat spacing = 20;
    return self.view.frame.size.height - BUTTON_HEIGHT - spacing;
}

#pragma mark - Asset Agnostic Methods

- (NSString *)formatAmount:(uint64_t)amount localCurrency:(BOOL)useLocalCurrency
{
    if (self.assetType == LegacyAssetTypeBitcoin) {
        return [NSNumberFormatter formatAmount:amount localCurrency:useLocalCurrency];
    } else if (self.assetType == LegacyAssetTypeBitcoinCash) {
        return [NSNumberFormatter formatBch:amount localCurrency:useLocalCurrency];
    }
    DLog(@"Warning: Unsupported asset type!");
    return nil;
}

- (NSString *)formatMoney:(uint64_t)amount localCurrency:(BOOL)useLocalCurrency
{
    if (self.assetType == LegacyAssetTypeBitcoin) {
        return [NSNumberFormatter formatMoney:amount localCurrency:useLocalCurrency];
    } else if (self.assetType == LegacyAssetTypeBitcoinCash) {
        return [NSNumberFormatter formatBchWithSymbol:amount localCurrency:useLocalCurrency];
    }
    DLog(@"Warning: Unsupported asset type!");
    return nil;
}

- (BOOL)canChangeFromAddress
{
    if (self.assetType == LegacyAssetTypeBitcoin) {
        return !([WalletManager.sharedInstance.wallet hasAccount] && ![WalletManager.sharedInstance.wallet hasLegacyAddresses:self.assetType] && [WalletManager.sharedInstance.wallet getActiveAccountsCount:self.assetType] == 1);
    } else if (self.assetType == LegacyAssetTypeBitcoinCash) {
        
    }
    return YES;
}

- (void)changePaymentFromAddress:(NSString *)address
{
    [WalletManager.sharedInstance.wallet changePaymentFromAddress:address isAdvanced:self.feeType == FeeTypeCustom assetType:self.assetType];
}

- (void)changePaymentFromAccount:(int)account
{
    [WalletManager.sharedInstance.wallet changePaymentFromAccount:account isAdvanced:self.feeType == FeeTypeCustom assetType:self.assetType];
}

- (void)getTransactionFeeWithUpdateType:(FeeUpdateType)updateType
{
    if (self.assetType == LegacyAssetTypeBitcoin) {
        [WalletManager.sharedInstance.wallet getTransactionFeeWithUpdateType:updateType];
    } else if (self.assetType == LegacyAssetTypeBitcoinCash) {
        id to = self.sendToAddress ? self.toAddress : [NSNumber numberWithInt:self.toAccount];
        [WalletManager.sharedInstance.wallet buildBitcoinCashPaymentTo:to amount:amountInSatoshi];
        [self showSummary];
    }
}

- (void)sweepPaymentRegular
{
    if (self.assetType == LegacyAssetTypeBitcoin) {
        [WalletManager.sharedInstance.wallet sweepPaymentRegular];
    } else if (self.assetType == LegacyAssetTypeBitcoinCash) {
        [self didGetMaxFee:[NSNumber numberWithLongLong:self.feeFromTransactionProposal] amount:[NSNumber numberWithLongLong:availableAmount] dust:0 willConfirm:NO];
    }
}

- (void)sweepPaymentAdvanced
{
    if (self.assetType == LegacyAssetTypeBitcoin) {
        [WalletManager.sharedInstance.wallet sweepPaymentAdvanced];
    } else if (self.assetType == LegacyAssetTypeBitcoinCash) {
        // No custom fee in bch
    }
}

- (void)changeSatoshiPerByte:(uint64_t)satoshiPerByte updateType:(FeeUpdateType)updateType
{
    if (self.assetType == LegacyAssetTypeBitcoin) {
        [WalletManager.sharedInstance.wallet changeSatoshiPerByte:satoshiPerByte updateType:updateType];
    } else if (self.assetType == LegacyAssetTypeBitcoinCash) {
        // No custom fee in bch
    }
}

- (void)checkIfOverspending
{
    if (self.assetType == LegacyAssetTypeBitcoin) {
        [WalletManager.sharedInstance.wallet checkIfOverspending];
    } else if (self.assetType == LegacyAssetTypeBitcoinCash) {
        [self didCheckForOverSpending:[NSNumber numberWithLongLong:availableAmount] fee:[NSNumber numberWithLongLong:self.feeFromTransactionProposal]];
    }
}

- (void)sendPaymentWithListener:(TransactionProgressListeners*)listener secondPassword:(NSString *)secondPassword
{
    if (self.assetType == LegacyAssetTypeBitcoin) {
        [WalletManager.sharedInstance.wallet sendPaymentWithListener:listener secondPassword:secondPassword];
    } else if (self.assetType == LegacyAssetTypeBitcoinCash) {
        [WalletManager.sharedInstance.wallet sendBitcoinCashPaymentWithListener:listener];
    }
}

#pragma mark - Address Book

- (NSString *)labelForLegacyAddress:(NSString *)address
{
    if ([[WalletManager.sharedInstance.wallet.addressBook objectForKey:address] length] > 0) {
        return [WalletManager.sharedInstance.wallet.addressBook objectForKey:address];
        
    }
    else if ([[WalletManager.sharedInstance.wallet allLegacyAddresses:self.assetType] containsObject:address]) {
        NSString *label = [WalletManager.sharedInstance.wallet labelForLegacyAddress:address assetType:self.assetType];
        if (label && ![label isEqualToString:@""])
            return label;
    }
    
    return address;
}

#pragma mark - Textfield Delegates

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if (![WalletManager.sharedInstance.wallet isInitialized]) {
        DLog(@"Tried to access Send textField when not initialized!");
        return NO;
    }
    
    if (textField == selectAddressTextField) {
        // If we only have one account and no legacy addresses -> can't change from address
        if ([self canChangeFromAddress]) {
            [self selectFromAddressClicked:textField];
        }
        return NO;  // Hide both keyboard and blinking cursor.
    }
    
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (self.tapGesture == nil) {
        self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard)];
        
        [self.view addGestureRecognizer:self.tapGesture];
    }
    
    if (textField == btcAmountField) {
        displayingLocalSymbolSend = NO;
    }
    else if (textField == fiatAmountField) {
        displayingLocalSymbolSend = YES;
    }
    
    [self doCurrencyConversion];
    
    self.transactionType = SendTransactionTypeRegular;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    self.exchangeAddressButton.hidden = NO;
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == btcAmountField || textField == fiatAmountField) {
        
        NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        NSArray  *points = [newString componentsSeparatedByString:@"."];
        NSLocale *locale = [textField.textInputMode.primaryLanguage isEqualToString:LOCALE_IDENTIFIER_AR] ? [NSLocale localeWithLocaleIdentifier:textField.textInputMode.primaryLanguage] : [NSLocale currentLocale];
        NSArray  *commas = [newString componentsSeparatedByString:[locale objectForKey:NSLocaleDecimalSeparator]];
        
        // Only one comma or point in input field allowed
        if ([points count] > 2 || [commas count] > 2)
            return NO;
        
        // Only 1 leading zero
        if (points.count == 1 || commas.count == 1) {
            if (range.location == 1 && ![string isEqualToString:@"."] && ![string isEqualToString:@","] && ![string isEqualToString:@"٫"] && [textField.text isEqualToString:@"0"]) {
                return NO;
            }
        }
        
        // When entering amount in BTC, max 8 decimal places
        if (textField == btcAmountField || textField == feeField) {
            // Max number of decimal places depends on bitcoin unit
            NSUInteger maxlength = [@(SATOSHI) stringValue].length - [@(SATOSHI / WalletManager.sharedInstance.latestMultiAddressResponse.symbol_btc.conversion) stringValue].length;
            
            if (points.count == 2) {
                NSString *decimalString = points[1];
                if (decimalString.length > maxlength) {
                    return NO;
                }
            }
            else if (commas.count == 2) {
                NSString *decimalString = commas[1];
                if (decimalString.length > maxlength) {
                    return NO;
                }
            }
        }
        
        // Fiat currencies have a max of 3 decimal places, most of them actually only 2. For now we will use 2.
        else if (textField == fiatAmountField) {
            if (points.count == 2) {
                NSString *decimalString = points[1];
                if (decimalString.length > 2) {
                    return NO;
                }
            }
            else if (commas.count == 2) {
                NSString *decimalString = commas[1];
                if (decimalString.length > 2) {
                    return NO;
                }
            }
        }
        
        if (textField == fiatAmountField) {
            // Convert input amount to internal value
            NSString *amountString = [newString stringByReplacingOccurrencesOfString:@"," withString:@"."];
            if (![amountString containsString:@"."]) {
                amountString = [newString stringByReplacingOccurrencesOfString:@"٫" withString:@"."];
            }
            amountInSatoshi = [WalletManager.sharedInstance.wallet conversionForBitcoinAssetType:self.assetType] * [amountString doubleValue];
        }
        else if (textField == btcAmountField) {
            amountInSatoshi = [NSNumberFormatter parseBitcoinValueFrom:newString];
        }
        
        if (amountInSatoshi > BTC_LIMIT_IN_SATOSHI) {
            return NO;
        } else {
            [self performSelector:@selector(doCurrencyConversion) withObject:nil afterDelay:0.1f];
            return YES;
        }
        
    } else if (textField == feeField) {
        
        NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        
        if ([newString containsString:@"."] ||
            [newString containsString:@","] ||
            [newString containsString:@"٫"]) return NO;
        
        if (newString.length == 0) {
            self.feeWarningLabel.hidden = YES;
            [lineBelowFeeField changeYPositionAnimated:[self defaultYPositionForWarningLabel] completion:nil];
        }

        [self performSelector:@selector(updateSatoshiPerByteAfterTextChange) withObject:nil afterDelay:0.1f];
        
        return YES;
    } else if (textField == toField) {
        NSString *entry = [textField.text stringByReplacingCharactersInRange:range withString:string];
        NSURL *bitpayURLCandidate = [NSURL URLWithString:entry];
        if (bitpayURLCandidate != nil) {
            if ([self isBitpayURL:bitpayURLCandidate] && self.assetType == LegacyAssetTypeBitcoin)
            {
                NSString *bitpayInvoiceID = [self invoiceIDFromBitPayURL:bitpayURLCandidate];
                [self handleBitpayInvoiceID:bitpayInvoiceID event:[BitpayUrlPasted createWithLegacyAssetType:self.assetType]];
                return YES;
            }
        }
        self.sendToAddress = true;
        self.toAddress = [textField.text stringByReplacingCharactersInRange:range withString:string];
        if (self.toAddress && [WalletManager.sharedInstance.wallet isValidAddress:self.toAddress assetType:self.assetType]) {
            [self selectToAddress:self.toAddress];
            self.addressSource = DestinationAddressSourcePaste;
            return NO;
        } else {
            self.exchangeAddressButton.hidden = self.toAddress.length > 0;
        }
        
        DLog(@"toAddress: %@", self.toAddress);
    }
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
    [textField resignFirstResponder];
    
    return YES;
}

- (void)updateFundsAvailable
{
    if (fiatAmountField.textColor == UIColor.error && btcAmountField.textColor == UIColor.error && [fiatAmountField.text isEqualToString:[NSNumberFormatter formatAmount:availableAmount localCurrency:YES]]) {
        [fundsAvailableButton setTitle:[NSString stringWithFormat:BC_STRING_USE_TOTAL_AVAILABLE_MINUS_FEE_ARGUMENT, [self formatMoney:availableAmount localCurrency:NO]] forState:UIControlStateNormal];
    } else {
        [fundsAvailableButton setTitle:[NSString stringWithFormat:BC_STRING_USE_TOTAL_AVAILABLE_MINUS_FEE_ARGUMENT,
                                        [self formatMoney:availableAmount localCurrency:displayingLocalSymbolSend]]
                                forState:UIControlStateNormal];
        [fundsAvailableButton setTitleColor:UIColor.brandSecondary forState:UIControlStateNormal];
    }
    
}

- (void)selectFromAddress:(NSString *)address
{
    self.sendFromAddress = true;
    
    NSString *addressOrLabel;
    NSString *label = [WalletManager.sharedInstance.wallet labelForLegacyAddress:address assetType:self.assetType];
    if (label && ![label isEqualToString:@""]) {
        addressOrLabel = label;
    }
    else {
        addressOrLabel = address;
    }
    
    selectAddressTextField.text = addressOrLabel;
    self.fromAddress = address;
    DLog(@"fromAddress: %@", address);
    
    [self changePaymentFromAddress:address];
    
    [self doCurrencyConversion];
}

- (void)selectToAddress:(NSString *)address
{
    self.sendToAddress = true;

    toField.text = [WalletManager.sharedInstance.wallet labelForLegacyAddress:address assetType:self.assetType];
    self.toAddress = address;
    DLog(@"toAddress: %@", address);
    
    self.exchangeAddressButton.hidden = self.addressSource != DestinationAddressSourceExchange;
    
    [WalletManager.sharedInstance.wallet changePaymentToAddress:address assetType:self.assetType];
    
    [self doCurrencyConversion];
}

- (void)selectFromAccount:(int)account
{
    self.sendFromAddress = false;
    
    availableAmount = [[WalletManager.sharedInstance.wallet getBalanceForAccount:account assetType:self.assetType] longLongValue];
    
    selectAddressTextField.text = [WalletManager.sharedInstance.wallet getLabelForAccount:account assetType:self.assetType];
    self.fromAccount = account;
    DLog(@"fromAccount: %@", [WalletManager.sharedInstance.wallet getLabelForAccount:account assetType:self.assetType]);
    
    [self changePaymentFromAccount:account];
    
    [self updateFundsAvailable];
    
    [self doCurrencyConversion];
}

- (void)selectToAccount:(int)account
{
    self.sendToAddress = false;

    toField.text = [WalletManager.sharedInstance.wallet getLabelForAccount:account assetType:self.assetType];
    self.toAccount = account;
    self.exchangeAddressButton.hidden = YES;
    
    self.toAddress = @"";
    DLog(@"toAccount: %@", [WalletManager.sharedInstance.wallet getLabelForAccount:account assetType:self.assetType]);
    
    [WalletManager.sharedInstance.wallet changePaymentToAccount:account assetType:self.assetType];
    
    [self doCurrencyConversion];
}

# pragma mark - AddressBook delegate

- (LegacyAssetType)getAssetType
{
    return self.assetType;
}

- (void)didSelectFromAddress:(NSString *)address
{
    [self selectFromAddress:address];
}

- (void)didSelectFromAccount:(int)account assetType:(LegacyAssetType)asset
{
    [self selectFromAccount:account];
}

- (void)didSelectToAddress:(NSString *)address
{
    [self selectToAddress:address];
    [self setDropdownAddressSource];
}

- (void)didSelectToAccount:(int)account assetType:(LegacyAssetType)asset
{
    [self selectToAccount:account];
    [self setDropdownAddressSource];
}

- (void)setDropdownAddressSource {
    self.addressSource = DestinationAddressSourceDropDown;
    [self.exchangeAddressButton setImage:[UIImage imageNamed:@"exchange-icon-small"] forState:UIControlStateNormal];
    toField.hidden = false;
    destinationAddressIndicatorLabel.hidden = true;
}

#pragma mark - Transaction Description Delegate

- (void)confirmButtonDidTap:(NSString *_Nullable)note
{
    self.noteToSet = note;
}

#pragma mark - Fee Calculation

- (void)getTransactionFeeWithSuccess:(void (^)(void))success error:(void (^)(void))error
{
    self.getTransactionFeeSuccess = success;
    
    [self getTransactionFeeWithUpdateType:FeeUpdateTypeConfirm];
}

- (void)didCheckForOverSpending:(NSNumber *)amount fee:(NSNumber *)fee
{
    if ([amount longLongValue] <= 0) {
        [self handleZeroSpendableAmount];
        return;
    }
    
    self.feeFromTransactionProposal = [fee longLongValue];
    
    __weak SendBitcoinViewController *weakSelf = self;
    
    [self getTransactionFeeWithSuccess:^{
        [weakSelf showSummary];
    } error:nil];
}

- (void)didGetMaxFee:(NSNumber *)fee amount:(NSNumber *)amount dust:(NSNumber *)dust willConfirm:(BOOL)willConfirm
{
    if ([amount longLongValue] <= 0) {
        [self handleZeroSpendableAmount];
        return;
    }
    
    self.feeFromTransactionProposal = [fee longLongValue];
    uint64_t maxAmount = [amount longLongValue];
    self.dust = dust == nil ? 0 : [dust longLongValue];
    
    DLog(@"SendViewController: got max fee of %lld", [fee longLongValue]);
    amountInSatoshi = maxAmount;
    [self doCurrencyConversion];
    
    if (willConfirm) {
        [self showSummary];
    }
}

- (void)didUpdateTotalAvailable:(NSNumber *)sweepAmount finalFee:(NSNumber *)finalFee
{
    availableAmount = [sweepAmount longLongValue];
    uint64_t fee = [finalFee longLongValue];
    
    if (self.assetType == LegacyAssetTypeBitcoinCash) self.feeFromTransactionProposal = fee;
    
    CGFloat warningLabelYPosition = [self defaultYPositionForWarningLabel];
    
    if (availableAmount <= 0) {
        [lineBelowFeeField changeYPositionAnimated:warningLabelYPosition + 30 completion:^(BOOL finished) {
            if (self.feeType == FeeTypeCustom) {
                [self setupFeeWarningLabelFrameSmall];
            } else {
                [self setupFeeWarningLabelFrameLarge];
            }
            self.feeWarningLabel.hidden = self->lineBelowFeeField.frame.origin.y == warningLabelYPosition;
        }];
        self.feeWarningLabel.text = BC_STRING_NOT_ENOUGH_FUNDS_TO_USE_FEE;
    } else {
        if ([self.feeWarningLabel.text isEqualToString:BC_STRING_NOT_ENOUGH_FUNDS_TO_USE_FEE]) {
            [lineBelowFeeField changeYPositionAnimated:warningLabelYPosition completion:nil];
            self.feeWarningLabel.hidden = YES;
        }
    }
    
    [self updateFeeAmountLabelText:fee];
    [self doCurrencyConversionAfterMultiAddress];
}

- (void)didGetFee:(NSNumber *)fee dust:(NSNumber *)dust txSize:(NSNumber *)txSize
{
    self.feeFromTransactionProposal = [fee longLongValue];
    self.recommendedForcedFee = [fee longLongValue];
    self.dust = dust == nil ? 0 : [dust longLongValue];
    self.txSize = [txSize longLongValue];
    
    if (self.getTransactionFeeSuccess) {
        self.getTransactionFeeSuccess();
    }
}

- (void)didChangeSatoshiPerByte:(NSNumber *)sweepAmount fee:(NSNumber *)fee dust:(NSNumber *)dust updateType:(FeeUpdateType)updateType
{
    availableAmount = [sweepAmount longLongValue];
    
    if (updateType != FeeUpdateTypeConfirm) {
        if (amountInSatoshi > availableAmount) {
            feeField.textColor = UIColor.error;
            [self disablePaymentButtons];
        } else {
            [self removeHighlightFromAmounts];
            feeField.textColor = UIColor.gray5;
            [self enablePaymentButtons];
        }
    }
    
    [self updateFundsAvailable];
    
    uint64_t feeValue = [fee longLongValue];

    self.feeFromTransactionProposal = feeValue;
    self.dust = dust == nil ? 0 : [dust longLongValue];
    [self updateFeeAmountLabelText:feeValue];
    
    if (updateType == FeeUpdateTypeConfirm) {
        [self showSummary];
    } else if (updateType == FeeUpdateTypeSweep) {
        [self sweepPaymentAdvanced];
    }
}

- (void)checkMaxFee
{
    [self checkIfOverspending];
}

- (void)updateSatoshiPerByteAfterTextChange
{
    [self updateSatoshiPerByteWithUpdateType:FeeUpdateTypeNoAction];
}

- (void)updateSatoshiPerByteWithUpdateType:(FeeUpdateType)feeUpdateType
{
    if (self.feeType == FeeTypeCustom) {
        uint64_t typedSatoshiPerByte = [feeField.text longLongValue];
        
        NSDictionary *limits = [self.fees objectForKey:DICTIONARY_KEY_FEE_LIMITS];
        
        if (typedSatoshiPerByte < [[limits objectForKey:DICTIONARY_KEY_FEE_LIMITS_MIN] longLongValue]) {
            DLog(@"Fee rate lower than recommended");
            
            CGFloat warningLabelYPosition = [self defaultYPositionForWarningLabel];
            
            if (feeField.text.length > 0) {
                if (IS_USING_SCREEN_SIZE_LARGER_THAN_5S) {
                    [lineBelowFeeField changeYPositionAnimated:warningLabelYPosition + 12 completion:^(BOOL finished) {
                        [self setupFeeWarningLabelFrameSmall];
                        self.feeWarningLabel.hidden = self->lineBelowFeeField.frame.origin.y == warningLabelYPosition;
                    }];
                } else {
                    [lineBelowFeeField changeYPositionAnimated:[self defaultYPositionForWarningLabel] completion:^(BOOL finished) {
                        [self setupFeeWarningLabelFrameSmall];
                        self.feeWarningLabel.hidden = NO;
                    }];
                }
                self.feeWarningLabel.text = BC_STRING_LOW_FEE_NOT_RECOMMENDED;
            }
        } else if (typedSatoshiPerByte > [[limits objectForKey:DICTIONARY_KEY_FEE_LIMITS_MAX] longLongValue] && !self.isBitpayPayPro) {
            DLog(@"Fee rate higher than recommended");
            
            CGFloat warningLabelYPosition = [self defaultYPositionForWarningLabel];

            if (feeField.text.length > 0) {
                if (IS_USING_SCREEN_SIZE_LARGER_THAN_5S) {
                    [lineBelowFeeField changeYPositionAnimated:warningLabelYPosition + 12 completion:^(BOOL finished) {
                        [self setupFeeWarningLabelFrameSmall];
                        self.feeWarningLabel.hidden = self->lineBelowFeeField.frame.origin.y == warningLabelYPosition;
                    }];
                } else {
                    [lineBelowFeeField changeYPositionAnimated:[self defaultYPositionForWarningLabel] completion:^(BOOL finished) {
                        [self setupFeeWarningLabelFrameSmall];
                        self.feeWarningLabel.hidden = NO;
                    }];
                }
                self.feeWarningLabel.text = BC_STRING_HIGH_FEE_NOT_NECESSARY;
            }
        } else {
            [lineBelowFeeField changeYPositionAnimated:[self defaultYPositionForWarningLabel] completion:nil];
            self.feeWarningLabel.hidden = YES;
        }
        
        [WalletManager.sharedInstance.wallet changeSatoshiPerByte:typedSatoshiPerByte updateType:feeUpdateType];
        
    } else if (self.feeType == FeeTypeRegular) {
        uint64_t regularRate = [[self.fees objectForKey:DICTIONARY_KEY_FEE_REGULAR] longLongValue];
        [self changeSatoshiPerByte:regularRate updateType:feeUpdateType];
    } else if (self.feeType == FeeTypePriority) {
        uint64_t priorityRate = [[self.fees objectForKey:DICTIONARY_KEY_FEE_PRIORITY] longLongValue];
        [WalletManager.sharedInstance.wallet changeSatoshiPerByte:priorityRate updateType:feeUpdateType];
    }
}

- (void)selectFeeType:(FeeType)feeType
{
    self.feeType = feeType;
    
    [self updateFeeLabels];
    
    [self updateSatoshiPerByteWithUpdateType:FeeUpdateTypeNoAction];

    [[ModalPresenter sharedInstance] closeModalWithTransition:kCATransitionFromLeft];
}

#pragma mark - Fee Selection Delegate

- (void)didSelectFeeType:(FeeType)feeType
{
    if (feeType == FeeTypeCustom) {
        BOOL hasSeenWarning = [[NSUserDefaults standardUserDefaults] boolForKey:USER_DEFAULTS_KEY_HAS_SEEN_CUSTOM_FEE_WARNING];
        if (!hasSeenWarning) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:BC_STRING_WARNING_TITLE message:BC_STRING_CUSTOM_FEE_WARNING preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:BC_STRING_CONTINUE style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self selectFeeType:feeType];
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:USER_DEFAULTS_KEY_HAS_SEEN_CUSTOM_FEE_WARNING];
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:nil]];
            TabControllerManager *tabControllerManager = [AppCoordinator sharedInstance].tabControllerManager;
            [tabControllerManager.tabViewController presentViewController:alert animated:YES completion:nil];
        } else {
            [self selectFeeType:feeType];
        }
    } else {
        [self selectFeeType:feeType];
    }
}

- (FeeType)selectedFeeType
{
    return self.feeType;
}

#pragma mark - Actions

- (void)setupTransferAll
{
    self.transferAllPaymentBuilder = [[TransferAllFundsBuilder alloc] initWithAssetType:self.assetType usingSendScreen:YES];
    self.transferAllPaymentBuilder.delegate = self;
}

- (void)archiveTransferredAddresses
{
    [[LoadingViewPresenter sharedInstance] showWith:[NSString stringWithFormat:BC_STRING_ARCHIVING_ADDRESSES]];
                                      
    [WalletManager.sharedInstance.wallet archiveTransferredAddresses:self.transferAllPaymentBuilder.transferAllAddressesTransferred];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishedArchivingTransferredAddresses) name:[ConstantsObjcBridge notificationKeyBackupSuccess] object:nil];
}

- (void)finishedArchivingTransferredAddresses
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[ConstantsObjcBridge notificationKeyBackupSuccess] object:nil];
    [[ModalPresenter sharedInstance] closeAllModals];
}

- (IBAction)selectFromAddressClicked:(id)sender
{
    if (![WalletManager.sharedInstance.wallet isInitialized]) {
        DLog(@"Tried to access select from screen when not initialized!");
        return;
    }
    
    BCAddressSelectionView *addressSelectionView = [[BCAddressSelectionView alloc] initWithWallet:WalletManager.sharedInstance.wallet selectMode:SelectModeSendFrom delegate:self];
    [[ModalPresenter sharedInstance] showModalWithContent:addressSelectionView closeType:ModalCloseTypeBack showHeader:true headerText:BC_STRING_SEND_FROM onDismiss:nil onResume:nil];
}

- (IBAction)addressBookClicked:(id)sender
{
    if (![WalletManager.sharedInstance.wallet isInitialized]) {
        DLog(@"Tried to access select to screen when not initialized!");
        return;
    }
    
    // TODO: IOS-2269: Display address dropdown

    BCAddressSelectionView *addressSelectionView = [[BCAddressSelectionView alloc] initWithWallet:WalletManager.sharedInstance.wallet selectMode:SelectModeSendTo delegate:self];
    [[ModalPresenter sharedInstance] showModalWithContent:addressSelectionView closeType:ModalCloseTypeBack showHeader:true headerText:BC_STRING_SEND_TO onDismiss:nil onResume:nil];
}

- (BOOL)isBitpayURL:(NSURL *)URL
{
    return [URL.absoluteString containsString:@"https://bitpay.com/"];
}

- (NSString * _Nullable)invoiceIDFromBitPayURL:(NSURL *)URL
{
    NSString *BTCPrefix = @"bitcoin:?r=";
    NSString *BCHPrefix = @"bitcoincash:?r=";
    NSString *bitpayPayload = URL.absoluteString;
    if ([bitpayPayload containsString:BTCPrefix]) {
        bitpayPayload = [bitpayPayload stringByReplacingOccurrencesOfString:BTCPrefix withString:@""];
    }
    if ([bitpayPayload containsString:BCHPrefix]) {
        bitpayPayload = [bitpayPayload stringByReplacingOccurrencesOfString:BCHPrefix withString:@""];
    }
    NSURL *modifiedURL = [NSURL URLWithString:bitpayPayload];
    if (modifiedURL == nil) {
        return nil;
    } else {
        NSString *invoiceID = [modifiedURL lastPathComponent];
        return invoiceID;
    }
}

- (void)handleBitpayInvoiceID:(NSString *)invoiceID event:(id<ObjcAnalyticsEvent> _Nonnull) event
{
    [self.analyticsRecorder recordWithEvent:event];
    [self.bitpayService bitpayPaymentRequestWithInvoiceID:invoiceID assetType:self.assetType completion:^(ObjcCompatibleBitpayObject * _Nullable paymentReq, NSError * _Nullable error) {
        if (error != nil) {
            DLog(@"Error when creating bitpay request: %@", error);
            return;
        }
        self.isBitpayPayPro = YES;
        [self disableInputs];

        //set required fee type to priority
        self.feeType = FeeTypePriority;
        [self updateFeeLabels];
        
        //Set toField to bitcoinLink url
        NSString *bitcoinLink = [NSString stringWithFormat: @"bitcoin:?r=%@", paymentReq.paymentUrl];
        self->toField.text = bitcoinLink;
        
        //Get decimal BTC amount from satoshi amount and set btcAmountField
        amountInSatoshi = paymentReq.amount;
        double amountInBtc = (double) paymentReq.amount / 100000000;
        NSString *amountDecimalNumber = [NSString stringWithFormat:@"%f", amountInBtc];
        
        self->btcAmountField.text = amountDecimalNumber;
        
        //Set toAddress to required BitPay paymentRequest address and update wallet internal payment address
        self.toAddress = paymentReq.address;
        self.sendToAddress = true;
        [WalletManager.sharedInstance.wallet changePaymentToAddress:paymentReq.address assetType:self.assetType];
        self.addressSource = DestinationAddressSourceBitPay;
        
        //Set merchant name
        NSString *merchant = [paymentReq.memo componentsSeparatedByString:@"for merchant "][1];
        self.bitpayMerchant = merchant;
        self.bitpayLabel.text = merchant;
        self.bitpayLabel.hidden = NO;
        self.bitpayLogo.hidden = NO;
        self.bitpayTimeRemainingText.hidden = NO;
        self.lineBelowBitpayLabel.hidden = NO;
        
        
        //Set time remaining string
        self.bitpayExpiration = paymentReq.expires;
        
        self.bitpayTimeRemainingText.textColor = UIColor.gray3;
        
        self.bitpayTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0 target: self selector: @selector(handleTimerTick:) userInfo: nil repeats: YES];
        
        [self performSelector:@selector(doCurrencyConversion) withObject:nil afterDelay:0.1f];
    }];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (metadataObjects != nil && [metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects firstObject];
        
        if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]) {
            [self performSelectorOnMainThread:@selector(stopReadingQRCode) withObject:nil waitUntilDone:NO];
            
            // do something useful with results
            dispatch_sync(dispatch_get_main_queue(), ^{
                if ([self.deepLinkQRCodeRouter handleWithDeepLink:[metadataObj stringValue]]) {
                    return;
                }

                AssetType type = [AssetTypeLegacyHelper convertFromLegacy:self.assetType];
                id<AssetURLPayload> payload = [AssetURLPayloadFactory createFromString:[metadataObj stringValue] assetType:type];

                NSString *address = payload.address;
                NSString *scheme = [AssetURLPayloadFactory schemeForAssetType:type];
                NSString *paymentRequestUrl = payload.paymentRequestUrl;

                if (paymentRequestUrl != nil) {
                    if ([paymentRequestUrl hasPrefix:@"https://bitpay.com/i/"] && self.assetType == LegacyAssetTypeBitcoin) {
                        NSString *invoiceId = payload.paymentRequestUrl;
                        invoiceId = [invoiceId stringByReplacingOccurrencesOfString:@"https://bitpay.com/i/" withString:@""];
                        [self handleBitpayInvoiceID:invoiceId event:[BitpayUrlScanned createWithLegacyAssetType:self.assetType]];
                        return;
                    } else {
                        return;
                    }
                } else {
                    if (address == nil || ![payload.schemeCompat isEqualToString:scheme] || ![WalletManager.sharedInstance.wallet isValidAddress:address assetType:self.assetType]) {
                        NSString *assetName = (type == AssetTypeBitcoin) ? @"Bitcoin" : @"Bitcoin Cash";
                        NSString *errorMessage = [NSString stringWithFormat:LocalizationConstantsObjcBridge.invalidXAddressY, assetName, address];
                        [AlertViewPresenter.sharedInstance standardErrorWithMessage:errorMessage title:LocalizationConstantsObjcBridge.error in:self handler:nil];
                        return;
                    }

                    self->toField.text = [WalletManager.sharedInstance.wallet labelForLegacyAddress:address assetType:self.assetType];
                    self.toAddress = address;
                    self.sendToAddress = true;
                    DLog(@"toAddress: %@", self.toAddress);
                    [self selectToAddress:self.toAddress];
                    
                    self.addressSource = DestinationAddressSourceQR;

                    NSString *amount;
                    if (self.assetType == LegacyAssetTypeBitcoin) {
                        amount = ((BitcoinURLPayload *) payload).amount;
                    } else if (self.assetType == LegacyAssetTypeBitcoinCash) {
                        amount = ((BitcoinCashURLPayload *) payload).amount;
                    }

                    if ([NSNumberFormatter stringHasBitcoinValue:amount]) {
                        if (WalletManager.sharedInstance.latestMultiAddressResponse.symbol_btc) {
                            NSDecimalNumber *amountDecimalNumber = [NSDecimalNumber decimalNumberWithString:amount];
                            amountInSatoshi = [[amountDecimalNumber decimalNumberByMultiplyingBy:(NSDecimalNumber *)[NSDecimalNumber numberWithDouble:SATOSHI]] longLongValue];
                        } else {
                            amountInSatoshi = 0.0;
                        }
                    } else {
                        [self performSelector:@selector(doCurrencyConversion) withObject:nil afterDelay:0.1f];
                        return;
                    }
                    
                    // If the amount is empty, open the amount field
                    if (amountInSatoshi == 0) {
                        self->btcAmountField.text = nil;
                        self->fiatAmountField.text = nil;
                        [self->fiatAmountField becomeFirstResponder];
                    }
                    
                    [self performSelector:@selector(doCurrencyConversion) withObject:nil afterDelay:0.1f];
                }
            });
        }
    }
}

- (IBAction)closeKeyboardClicked:(id)sender
{
    [btcAmountField resignFirstResponder];
    [fiatAmountField resignFirstResponder];
    [toField resignFirstResponder];
    [feeField resignFirstResponder];
}

- (IBAction)feeOptionsClicked:(UIButton *)sender
{
    BCFeeSelectionView *feeSelectionView = [[BCFeeSelectionView alloc] initWithFrame:[UIApplication sharedApplication].keyWindow.frame];
    feeSelectionView.delegate = self;
    [[ModalPresenter sharedInstance] showModalWithContent:feeSelectionView closeType:ModalCloseTypeBack showHeader:true headerText:BC_STRING_FEE onDismiss:nil onResume:nil];
}

- (IBAction)labelAddressClicked:(id)sender
{
    [WalletManager.sharedInstance.wallet addToAddressBook:toField.text label:labelAddressTextField.text];
    
    [[ModalPresenter sharedInstance] closeModalWithTransition:kCATransitionFade];
    labelAddressTextField.text = @"";
    
    // Complete payment
    [self showSummary];
}

- (IBAction)useAllClicked:(id)sender
{
    [self reportFormUseBalanceClick];
    
    [btcAmountField resignFirstResponder];
    [fiatAmountField resignFirstResponder];
    
    [self sweepPaymentRegular];
    
    self.transactionType = SendTransactionTypeSweep;
}

- (void)feeInformationButtonClicked
{
    NSString *title = BC_STRING_FEE_INFORMATION_TITLE;
    NSString *message = BC_STRING_FEE_INFORMATION_MESSAGE;
    
    if (self.feeType != FeeTypeCustom) {
        message = [message stringByAppendingString:BC_STRING_FEE_INFORMATION_MESSAGE_APPEND_REGULAR_SEND];
    }
    
    if (self.surgeIsOccurring || [[NSUserDefaults standardUserDefaults] boolForKey:USER_DEFAULTS_KEY_DEBUG_SIMULATE_SURGE]) {
        message = [message stringByAppendingString:[NSString stringWithFormat:@"\n\n%@", BC_STRING_SURGE_OCCURRING_MESSAGE]];
    }

    if (self.dust > 0) {
        message = [message stringByAppendingString:[NSString stringWithFormat:@"\n\n%@", BC_STRING_FEE_INFORMATION_DUST]];
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:nil]];
    [[NSNotificationCenter defaultCenter] addObserver:alert selector:@selector(autoDismiss) name:ConstantsObjcBridge.notificationKeyReloadToDismissViews object:nil];
    TabControllerManager *tabControllerManager = [AppCoordinator sharedInstance].tabControllerManager;
    [tabControllerManager.tabViewController presentViewController:alert animated:YES completion:nil];
}

- (IBAction)sendPaymentClicked:(id)sender
{
    [self reportSendFormConfirmClick];
    
    if ([self.toAddress length] == 0) {
        self.toAddress = toField.text;
        DLog(@"toAddress: %@", self.toAddress);
    }
    
    if ([self.toAddress length] == 0) {
        [self showErrorBeforeSending:BC_STRING_YOU_MUST_ENTER_DESTINATION_ADDRESS];
        return;
    }
    
    if (self.sendToAddress && ![WalletManager.sharedInstance.wallet isValidAddress:self.toAddress assetType:self.assetType]) {
        [self showErrorBeforeSending:BC_STRING_INVALID_TO_BITCOIN_ADDRESS];
        return;
    }
    
    if (!self.sendFromAddress && !self.sendToAddress && self.fromAccount == self.toAccount) {
        [self showErrorBeforeSending:BC_STRING_FROM_TO_DIFFERENT];
        return;
    }
    
    if (self.sendFromAddress && self.sendToAddress && [self.fromAddress isEqualToString:self.toAddress]) {
        [self showErrorBeforeSending:BC_STRING_FROM_TO_ADDRESS_DIFFERENT];
        return;
    }
    
    uint64_t value = amountInSatoshi;
    // Convert input amount to internal value
    NSString *language = btcAmountField.textInputMode.primaryLanguage;
    NSLocale *locale = language ? [NSLocale localeWithLocaleIdentifier:language] : [NSLocale currentLocale];
    NSString *amountString = [btcAmountField.text stringByReplacingOccurrencesOfString:[locale objectForKey:NSLocaleDecimalSeparator] withString:@"."];
    
    NSString *europeanComma = @",";
    NSString *arabicComma= @"٫";
    
    if ([amountString containsString:europeanComma]) {
        amountString = [btcAmountField.text stringByReplacingOccurrencesOfString:europeanComma withString:@"."];
    } else if ([amountString containsString:arabicComma]) {
        amountString = [btcAmountField.text stringByReplacingOccurrencesOfString:arabicComma withString:@"."];
    }
    if (value <= 0 || [amountString doubleValue] <= 0) {
        [self showErrorBeforeSending:BC_STRING_INVALID_SEND_VALUE];
        return;
    }
    
    [self hideKeyboard];
    
    [self disablePaymentButtons];
    
    self.transactionType = SendTransactionTypeRegular;
    
    if (self.feeType == FeeTypeCustom) {
        [self updateSatoshiPerByteWithUpdateType:FeeUpdateTypeConfirm];
    } else {
        [self checkMaxFee];
    }
    
    [WalletManager.sharedInstance.wallet getSurgeStatus];
}

@end
