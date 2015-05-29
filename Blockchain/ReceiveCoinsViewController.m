//
//  ReceiveCoinsViewControllerViewController.m
//  Blockchain
//
//  Created by Ben Reeves on 17/03/2012.
//  Copyright (c) 2012 Qkos Services Ltd. All rights reserved.
//

#import "ReceiveCoinsViewController.h"
#import "AppDelegate.h"
#import "ReceiveTableCell.h"
#import "Address.h"
#import "PrivateKeyReader.h"
#import <Social/Social.h>
#import <Twitter/Twitter.h>

@implementation ReceiveCoinsViewController

@synthesize activeKeys;
@synthesize archivedKeys;

Boolean didClickAccount = NO;
int clickedAccount;

UILabel *mainAddressLabel;

NSString *mainAddress;
NSString *mainLabel;

NSString *detailAddress;
NSString *detailLabel;

UIActionSheet *popupAccount;
UIActionSheet *popupAddressUnArchive;
UIActionSheet *popupAddressArchive;

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.frame = CGRectMake(0, 0, app.window.frame.size.width,
                                 app.window.frame.size.height - DEFAULT_HEADER_HEIGHT - DEFAULT_FOOTER_HEIGHT);
    
    tableView.backgroundColor = [UIColor whiteColor];
    
    float imageWidth = 190;
    
    qrCodeMainImageView = [[UIImageView alloc] initWithFrame:CGRectMake((self.view.frame.size.width - imageWidth) / 2, 25, imageWidth, imageWidth)];
    qrCodeMainImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    UITapGestureRecognizer *tapMainQRGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mainQRClicked:)];
    [qrCodeMainImageView addGestureRecognizer:tapMainQRGestureRecognizer];
    qrCodeMainImageView.userInteractionEnabled = YES;
    
    // The more actions button will be added to the top menu bar
    [moreActionsButton removeFromSuperview];
    moreActionsButton.alpha = 0.0f;
    moreActionsButton.frame = CGRectMake(0, 14, moreActionsButton.frame.size.width, moreActionsButton.frame.size.height);
    
    // iPhone4/4S
    if ([[UIScreen mainScreen] bounds].size.height < 568) {
        int reduceImageSizeBy = 60;
        
        // Smaller QR Code Image
        qrCodeMainImageView.frame = CGRectMake(qrCodeMainImageView.frame.origin.x + reduceImageSizeBy / 2,
                                               qrCodeMainImageView.frame.origin.y - 10,
                                               qrCodeMainImageView.frame.size.width - reduceImageSizeBy,
                                               qrCodeMainImageView.frame.size.height - reduceImageSizeBy);
        
        // Move everything up on label view
        UIView *mainView = labelTextField.superview;
        
        for (UIView *view in mainView.subviews) {
            CGRect frame = view.frame;
            frame.origin.y -= 45;
            view.frame = frame;
        }
    }
    
    qrCodePaymentImageView.frame = CGRectMake(qrCodeMainImageView.frame.origin.x,
                                              qrCodeMainImageView.frame.origin.y,
                                              qrCodeMainImageView.frame.size.width,
                                              qrCodeMainImageView.frame.size.height);
    
    UITapGestureRecognizer *tapDetailQRGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(copyAddressClicked:)];
    [qrCodePaymentImageView addGestureRecognizer:tapDetailQRGestureRecognizer];
    qrCodePaymentImageView.userInteractionEnabled = YES;
    
    // iPhone4/4S
    if ([[UIScreen mainScreen] bounds].size.height < 568) {
        // Smaller QR Code Image
        qrCodePaymentImageView.frame = CGRectMake(qrCodeMainImageView.frame.origin.x,
                                               qrCodeMainImageView.frame.origin.y - 10,
                                               qrCodeMainImageView.frame.size.width,
                                               qrCodeMainImageView.frame.size.height);
    }
    
    optionsTitleLabel.frame = CGRectMake(optionsTitleLabel.frame.origin.x,
                                         qrCodePaymentImageView.frame.origin.y + qrCodePaymentImageView.frame.size.height + 3,
                                         optionsTitleLabel.frame.size.width,
                                         optionsTitleLabel.frame.size.height);
    
    popupAccount = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:BC_STRING_CANCEL destructiveButtonTitle:nil otherButtonTitles:
                    BC_STRING_SHARE_ON_TWITTER,
                    BC_STRING_SHARE_ON_FACEBOOK,
                    BC_STRING_SHARE_VIA_EMAIL,
                    BC_STRING_SHARE_VIA_SMS,
                    BC_STRING_COPY_ADDRESS,
                    nil];
    
    popupAddressArchive = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:BC_STRING_CANCEL destructiveButtonTitle:nil otherButtonTitles:
                           BC_STRING_SHARE_ON_TWITTER,
                           BC_STRING_SHARE_ON_FACEBOOK,
                           BC_STRING_SHARE_VIA_EMAIL,
                           BC_STRING_SHARE_VIA_SMS,
                           BC_STRING_COPY_ADDRESS,
                           BC_STRING_LABEL_ADDRESS,
                           BC_STRING_ARCHIVE_ADDRESS,
                           nil];
    
    popupAddressUnArchive = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:BC_STRING_CANCEL destructiveButtonTitle:nil otherButtonTitles:
                             BC_STRING_SHARE_ON_TWITTER,
                             BC_STRING_SHARE_ON_FACEBOOK,
                             BC_STRING_SHARE_VIA_EMAIL,
                             BC_STRING_SHARE_VIA_SMS,
                             BC_STRING_COPY_ADDRESS,
                             BC_STRING_LABEL_ADDRESS,
                             BC_STRING_UNARCHIVE_ADDRESS,
                             nil];
    
    [self reload];
}

- (void)reload
{
    self.activeKeys = [app.wallet activeLegacyAddresses];
    self.archivedKeys = [app.wallet archivedLegacyAddresses];
    
    // Reset the requested amount when switching currencies
    requestAmountTextField.text = nil;
    
    if (app->symbolLocal && app.latestResponse.symbol_local && app.latestResponse.symbol_local.conversion > 0) {
        [btcButton setTitle:app.latestResponse.symbol_local.code forState:UIControlStateNormal];
        displayingLocalSymbol = TRUE;
    } else if (app.latestResponse.symbol_btc) {
        [btcButton setTitle:app.latestResponse.symbol_btc.symbol forState:UIControlStateNormal];
        displayingLocalSymbol = FALSE;
    }
    
    // Show table header with the QR code of an address from the default account
    float imageWidth = qrCodeMainImageView.frame.size.width;

    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, imageWidth + 50)];
    
    // Get an address: the first empty receive address for the default HD account
    // Or the first active legacy address if there are no HD accounts
    if ([app.wallet getAccountsCount] > 0) {
        int defaultAccountIndex = [app.wallet getDefaultAccountIndex];
        mainAddress = [app.wallet getReceiveAddressForAccount:defaultAccountIndex];
    }
    else if (activeKeys.count > 0) {
        for (NSString *address in activeKeys) {
            if (![app.wallet isWatchOnlyLegacyAddress:address]) {
                mainAddress = address;
                break;
            }
        }
    }
    
    if ([app.wallet getAccountsCount] > 0 || activeKeys.count > 0) {

        qrCodeMainImageView.image = [self qrImageFromAddress:mainAddress];

        [headerView addSubview:qrCodeMainImageView];
        
        // Label of the default HD account
        mainAddressLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, imageWidth + 30, self.view.frame.size.width - 40, 18)];
        if ([app.wallet getAccountsCount] > 0) {
            int defaultAccountIndex = [app.wallet getDefaultAccountIndex];
            mainLabel = [app.wallet getLabelForAccount:defaultAccountIndex];
        }
        // Label of the default legacy address
        else {
            NSString *label = [app.wallet labelForLegacyAddress:mainAddress];
            if (label.length > 0) {
                mainLabel = label;
            }
            else {
                mainLabel = mainAddress;
            }
        }
        
        mainAddressLabel.text = mainLabel;
        
        mainAddressLabel.font = [UIFont systemFontOfSize:15];
        mainAddressLabel.textAlignment = NSTextAlignmentCenter;
        mainAddressLabel.textColor = [UIColor blackColor];
        [mainAddressLabel setMinimumScaleFactor:.5f];
        [mainAddressLabel setAdjustsFontSizeToFitWidth:YES];
        [headerView addSubview:mainAddressLabel];
    }
    
    tableView.tableHeaderView = headerView;
    
    [tableView reloadData];
}

#pragma mark - Helpers

- (NSString *)getAddress:(NSIndexPath*)indexPath
{
    NSString *addr = nil;
    
    if ([indexPath section] == 1)
        addr = [activeKeys objectAtIndex:[indexPath row]];
    else if ([indexPath section] == 2)
        addr = [archivedKeys objectAtIndex:[indexPath row]];
    
    return addr;
}

- (NSString *)uriURL
{
    double amount = (double)[self getInputAmountInSatoshi] / SATOSHI;
    
    app.btcFormatter.usesGroupingSeparator = NO;
    NSString *amountString = [app.btcFormatter stringFromNumber:[NSNumber numberWithDouble:amount]];
    app.btcFormatter.usesGroupingSeparator = YES;
    
    amountString = [amountString stringByReplacingOccurrencesOfString:@"," withString:@"."];
    
    return [NSString stringWithFormat:@"bitcoin://%@?amount=%@", self.clickedAddress, amountString];
}

- (uint64_t)getInputAmountInSatoshi
{
    NSString *requestedAmountString = [requestAmountTextField.text stringByReplacingOccurrencesOfString:@"," withString:@"."];
    
    if (displayingLocalSymbol) {
        return app.latestResponse.symbol_local.conversion * [requestedAmountString doubleValue];
    } else {
        return [app.wallet parseBitcoinValue:requestedAmountString];
    }
}

- (void)doCurrencyConversion
{
    uint64_t amount = [self getInputAmountInSatoshi];
    
    [btcButton setBackgroundColor:COLOR_TEXT_FIELD_GRAY];
    [fiatButton setBackgroundColor:COLOR_TEXT_FIELD_GRAY];
    
    if (displayingLocalSymbol) {
        [btcButton setBackgroundImage:nil forState:UIControlStateNormal];
        [btcButton setTitleColor:COLOR_FOREGROUND_GRAY forState:UIControlStateNormal];
        [btcButton setTitle:[app formatMoney:amount localCurrency:FALSE] forState:UIControlStateNormal];
        
        // Highlight
        [fiatButton setBackgroundImage:[UIImage imageNamed: @"tab_left"] forState:UIControlStateNormal];
        [fiatButton setTitleColor:COLOR_BLOCKCHAIN_BLUE forState:UIControlStateNormal];
        NSString *amountFormatted = [app.latestResponse.symbol_local.symbol stringByAppendingString:requestAmountTextField.text];
        [fiatButton setTitle:amountFormatted forState:UIControlStateNormal];
    } else {
        // Highlight
        [btcButton setBackgroundImage:[UIImage imageNamed:@"tab_right"] forState:UIControlStateNormal];
        [btcButton setTitleColor:COLOR_BLOCKCHAIN_BLUE forState:UIControlStateNormal];
        NSString *amountFormatted = [requestAmountTextField.text stringByAppendingFormat:@" %@", app.latestResponse.symbol_btc.symbol];
        [btcButton setTitle:amountFormatted forState:UIControlStateNormal];
        
        [fiatButton setBackgroundImage:nil forState:UIControlStateNormal];
        [fiatButton setTitleColor:COLOR_FOREGROUND_GRAY forState:UIControlStateNormal];
        [fiatButton setTitle:[app formatMoney:amount localCurrency:TRUE] forState:UIControlStateNormal];
    }
}

- (NSString *)getKey:(NSIndexPath*)indexPath
{
    NSString *key;
    
    if ([indexPath section] == 0)
        key = [activeKeys objectAtIndex:[indexPath row]];
    else
        key = [archivedKeys objectAtIndex:[indexPath row]];
    
    return key;
}

- (UIImage *)qrImageFromAddress:(NSString *)address
{
    NSString *addressURL = [NSString stringWithFormat:@"bitcoin:%@", address];
    
    return [self createQRImageFromString:addressURL];
}

- (UIImage *)qrImageFromAddress:(NSString *)address amount:(double)amount
{
    app.btcFormatter.usesGroupingSeparator = NO;
    NSString *amountString = [app.btcFormatter stringFromNumber:[NSNumber numberWithDouble:amount]];
    app.btcFormatter.usesGroupingSeparator = YES;
    
    amountString = [amountString stringByReplacingOccurrencesOfString:@"," withString:@"."];
    
    NSString *addressURL = [NSString stringWithFormat:@"bitcoin:%@?amount=%@", address, amountString];
    
    return [self createQRImageFromString:addressURL];
}

- (UIImage *)createQRImageFromString:(NSString *)string
{
    return [self createNonInterpolatedUIImageFromCIImage:[self createQRFromString:string] withScale:10*[[UIScreen mainScreen] scale]];
}

- (CIImage *)createQRFromString:(NSString *)qrString
{
    // Need to convert the string to a UTF-8 encoded NSData object
    NSData *stringData = [qrString dataUsingEncoding:NSUTF8StringEncoding];
    
    // Create the filter
    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    // Set the message content and error-correction level
    [qrFilter setValue:stringData forKey:@"inputMessage"];
    [qrFilter setValue:@"M" forKey:@"inputCorrectionLevel"];
    
    return qrFilter.outputImage;
}

- (UIImage *)createNonInterpolatedUIImageFromCIImage:(CIImage *)image withScale:(CGFloat)scale
{
    // Render the CIImage into a CGImage
    CGImageRef cgImage = [[CIContext contextWithOptions:nil] createCGImage:image fromRect:image.extent];
    
    // Now we'll rescale using CoreGraphics
    UIGraphicsBeginImageContext(CGSizeMake(image.extent.size.width * scale, image.extent.size.width * scale));
    CGContextRef context = UIGraphicsGetCurrentContext();
    // We don't want to interpolate (since we've got a pixel-correct image)
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
    CGContextDrawImage(context, CGContextGetClipBoundingBox(context), cgImage);
    
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    
    // Tidy up
    UIGraphicsEndImageContext();
    CGImageRelease(cgImage);
    
    // Rotate the image
    UIImage *qrImage = [UIImage imageWithCGImage:[scaledImage CGImage]
                                           scale:[scaledImage scale]
                                     orientation:UIImageOrientationDownMirrored];
    
    return qrImage;
}

- (void)setQRPayment
{
    double amount = (double)[self getInputAmountInSatoshi] / SATOSHI;
    
    UIImage *image = [self qrImageFromAddress:self.clickedAddress amount:amount];
    
    qrCodePaymentImageView.image = image;
    qrCodePaymentImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    [self doCurrencyConversion];
}

# pragma mark - MFMailComposeViewControllerDelegate delegates

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    switch (result) {
        case MFMailComposeResultCancelled:
            break;
            
        case MFMailComposeResultFailed:
        {
            UIAlertView *warningAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Failed to send email!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [warningAlert show];
            break;
        }
            
        case MFMailComposeResultSent:
            break;
            
        case MFMailComposeResultSaved:
            break;
            
        default:
            break;
    }
    
    [controller dismissViewControllerAnimated:YES completion:nil];
    
    [self toggleKeyboard];
}

# pragma mark - MFMessageComposeViewControllerDelegate delegates

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult) result
{
    switch (result) {
        case MessageComposeResultCancelled:
            break;
            
        case MessageComposeResultFailed:
        {
            UIAlertView *warningAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Failed to send SMS!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [warningAlert show];
            break;
        }
            
        case MessageComposeResultSent:
            break;
            
        default:
            break;
    }
    
    [controller dismissViewControllerAnimated:YES completion:nil];
    
    [self toggleKeyboard];
}

#pragma mark - Actions

- (IBAction)moreActionsClicked:(id)sender
{
    if (didClickAccount) {
        [popupAccount showInView:[UIApplication sharedApplication].keyWindow];
    }
    else {
        if ([archivedKeys containsObject:self.clickedAddress]) {
            [popupAddressUnArchive showInView:[UIApplication sharedApplication].keyWindow];
        }
        else {
            [popupAddressArchive showInView:[UIApplication sharedApplication].keyWindow];
        }
    }
}

- (IBAction)btcCodeClicked:(id)sender
{
    // Ignore click when already selected
    if ((sender == fiatButton && displayingLocalSymbol) ||
        (sender == btcButton && !displayingLocalSymbol)) {
        return;
    }
    
    [app toggleSymbol];
    [self setQRPayment];
}

- (IBAction)scanKeyClicked:(id)sender
{
    PrivateKeyReader *reader = [[PrivateKeyReader alloc] initWithSuccess:^(NSString* privateKeyString) {
        [app.wallet addKey:privateKeyString];
        
        [app.wallet loading_stop];
    } error:nil];
    
    [app.slidingViewController presentViewController:reader animated:YES completion:nil];
}

- (IBAction)labelSaveClicked:(id)sender
{
    NSString *label = [labelTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSMutableCharacterSet *allowedCharSet = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
    [allowedCharSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
     
    if ([label rangeOfCharacterFromSet:[allowedCharSet invertedSet]].location != NSNotFound) {
        [app standardNotify:BC_STRING_LABEL_MUST_BE_ALPHANUMERIC];
        return;
    }
    
    NSString *addr = self.clickedAddress;
    
    [app.wallet setLabel:label forLegacyAddress:addr];
    
    [self reload];
    
    [app closeModalWithTransition:kCATransitionFade];
}

- (IBAction)mainQRClicked:(id)sender
{
    // Copy address to clipboard
    [UIPasteboard generalPasteboard].string = mainAddress;

    [UIView animateWithDuration:ANIMATION_DURATION animations:^{
        mainAddressLabel.alpha = 0.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:ANIMATION_DURATION animations:^{
            mainAddressLabel.text = mainAddress;
            mainAddressLabel.alpha = 1.0;
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:ANIMATION_DURATION animations:^{
                    mainAddressLabel.alpha = 0.0;
                } completion:^(BOOL finished) {
                    [UIView animateWithDuration:ANIMATION_DURATION animations:^{
                        mainAddressLabel.text = mainLabel;
                        mainAddressLabel.alpha = 1.0;
                    }];
                }];
            });
        }];
    }];
}

- (IBAction)copyAddressClicked:(id)sender
{
    [UIPasteboard generalPasteboard].string = detailAddress;
    
    [UIView animateWithDuration:ANIMATION_DURATION animations:^{
        optionsTitleLabel.alpha = 0.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:ANIMATION_DURATION animations:^{
            optionsTitleLabel.text = detailAddress;
            optionsTitleLabel.alpha = 1.0;
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:ANIMATION_DURATION animations:^{
                    optionsTitleLabel.alpha = 0.0;
                } completion:^(BOOL finished) {
                    [UIView animateWithDuration:ANIMATION_DURATION animations:^{
                        optionsTitleLabel.text = detailLabel;
                        optionsTitleLabel.alpha = 1.0;
                    }];
                }];
            });
        }];
    }];
}

- (IBAction)shareByTwitter:(id)sender
{
    SLComposeViewController *composeController = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
    
    [composeController setInitialText:[self formatPaymentRequest:@""]];
    [composeController addURL: [NSURL URLWithString:[self uriURL]]];
    
    [self presentViewController:composeController animated:YES completion:nil];
    
    composeController.completionHandler = ^(SLComposeViewControllerResult result) {
        [self toggleKeyboard];
    };
}

- (IBAction)shareByFacebook:(id)sender
{
    SLComposeViewController *composeController = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
    
    [composeController setInitialText:[self formatPaymentRequest:@""]];
    [composeController addURL: [NSURL URLWithString:[self uriURL]]];
    
    [self presentViewController:composeController animated:YES completion:nil];
    
    composeController.completionHandler = ^(SLComposeViewControllerResult result) {
        [self toggleKeyboard];
    };
}

- (NSString*)formatPaymentRequest:(NSString*)url
{
    return [NSString stringWithFormat:BC_STRING_PAYMENT_REQUEST, url];
}

- (NSString*)formatPaymentRequestHTML:(NSString*)url
{
    return [NSString stringWithFormat:BC_STRING_PAYMENT_REQUEST_HTML, url];
}

- (IBAction)shareByMessageClicked:(id)sender
{
    if([MFMessageComposeViewController canSendText]) {
        MFMessageComposeViewController *messageController = [[MFMessageComposeViewController alloc] init];
        [messageController setMessageComposeDelegate:self];
        [messageController setSubject:BC_STRING_PAYMENT_REQUEST_TITLE];
        [messageController setBody:[self formatPaymentRequest:[self uriURL]]];
        
        [self toggleKeyboard];
        [app.tabViewController presentViewController:messageController animated:YES completion:nil];
    }
    else {
        UIAlertView *warningAlert = [[UIAlertView alloc] initWithTitle:BC_STRING_ERROR message:BC_STRING_DEVICE_NO_SMS delegate:nil cancelButtonTitle:BC_STRING_OK otherButtonTitles:nil];
        [warningAlert show];
    }
}

- (IBAction)shareByEmailClicked:(id)sender
{
    if([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
        [mailController setMailComposeDelegate:self];
        NSData *jpegData = UIImageJPEGRepresentation(qrCodePaymentImageView.image, 1);
        [mailController addAttachmentData:jpegData mimeType:@"image/jpeg" fileName:@"QR code image"];
        [mailController setSubject:BC_STRING_PAYMENT_REQUEST_TITLE];
        [mailController setMessageBody:[self formatPaymentRequestHTML:[self uriURL]] isHTML:YES];
        
        [self toggleKeyboard];
        [app.tabViewController presentViewController:mailController animated:YES completion:nil];
    }
    else {
        UIAlertView *warningAlert = [[UIAlertView alloc] initWithTitle:BC_STRING_ERROR message:BC_STRING_DEVICE_NO_EMAIL delegate:nil cancelButtonTitle:BC_STRING_OK otherButtonTitles:nil];
        [warningAlert show];
    }
}

- (IBAction)labelAddressClicked:(id)sender
{
    NSString *addr = self.clickedAddress;
    NSString *label = [app.wallet labelForLegacyAddress:addr];
    
    labelAddressLabel.text = addr;
    
    if (label && label.length > 0) {
        labelTextField.text = label;
    }
    
    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    saveButton.frame = CGRectMake(0, 0, self.view.frame.size.width, 46);
    saveButton.backgroundColor = COLOR_BUTTON_GRAY;
    [saveButton setTitle:BC_STRING_SAVE forState:UIControlStateNormal];
    [saveButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    saveButton.titleLabel.font = [UIFont systemFontOfSize:17.0];
    
    [saveButton addTarget:self action:@selector(labelSaveClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    [labelTextField setReturnKeyType:UIReturnKeyDone];
    labelTextField.delegate = self;
    
    labelTextField.inputAccessoryView = saveButton;
    
    [app showModalWithContent:labelAddressView closeType:ModalCloseTypeClose headerText:BC_STRING_LABEL_ADDRESS onDismiss:^() {
        self.clickedAddress = nil;
        labelTextField.text = nil;
    } onResume:nil];
    
    [labelTextField becomeFirstResponder];
}

- (IBAction)archiveAddressClicked:(id)sender
{
    NSString *addr = self.clickedAddress;
    NSInteger tag = [app.wallet tagForLegacyAddress:addr];
    
    if (tag == 2) {
        [app.wallet unArchiveLegacyAddress:addr];
    }
    else {
        // Need at least one active address
        if (activeKeys.count == 1 && ![app.wallet didUpgradeToHd]) {
            [app closeModalWithTransition:kCATransitionFade];
            
            [app standardNotify:BC_STRING_AT_LEAST_ONE_ACTIVE_ADDRESS];
            
            return;
        }
        
        [app.wallet archiveLegacyAddress:addr];
    }
    
    [self reload];
    
    [app closeModalWithTransition:kCATransitionFade];
}


- (void)toggleKeyboard
{
    if ([requestAmountTextField isFirstResponder]) {
        [requestAmountTextField resignFirstResponder];
    } else {
        [requestAmountTextField becomeFirstResponder];
    }
}

# pragma mark - UIActionSheet delegate

- (void)actionSheet:(UIActionSheet *)popup clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (popup == popupAccount && buttonIndex > 4) {
        return;
    }
    
    switch (buttonIndex) {
        case 0:
            [self shareByTwitter:nil];
            break;
        case 1:
            [self shareByFacebook:nil];
            break;
        case 2:
            [self shareByEmailClicked:nil];
            break;
        case 3:
            [self shareByMessageClicked:nil];
            break;
        case 4:
            [self copyAddressClicked:nil];
            break;
        case 5:
            [self labelAddressClicked:nil];
            break;
        case 6:
            [self archiveAddressClicked:nil];
            break;
        default:
            break;
    }
}

# pragma mark - UITextField delegates

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if ([[UIScreen mainScreen] bounds].size.height < 568) {
        self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleKeyboard)];
        [app.modalView addGestureRecognizer:self.tapGesture];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
    if (textField == labelTextField) {
        [self labelSaveClicked:nil];
        return YES;
    }
    
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    NSArray  *points = [newString componentsSeparatedByString:@"."];
    NSArray  *commas = [newString componentsSeparatedByString:@","];
    
    // Only one comma or point in input field allowed
    if ([points count] > 2 || [commas count] > 2)
        return NO;
    
    // Only 1 leading zero
    if (points.count == 1 || commas.count == 1) {
        if (range.location == 1 && ![string isEqualToString:@"."] && ![string isEqualToString:@","] && [textField.text isEqualToString:@"0"]) {
            return NO;
        }
    }
    
    // When entering amount in BTC, max 8 decimal places
    if (!displayingLocalSymbol) {
        // Max number of decimal places depends on bitcoin unit
        NSUInteger maxlength = [@(SATOSHI) stringValue].length - [@(SATOSHI / app.latestResponse.symbol_btc.conversion) stringValue].length;
        
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
    else {
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
    
    [self performSelector:@selector(setQRPayment) withObject:nil afterDelay:0.1f];
    
    return YES;
}

#pragma mark - UITableview Delegates

- (void)tableView:(UITableView *)_tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    didClickAccount = (indexPath.section == 0);
    
    if (indexPath.section == 0) {
        int row = (int) indexPath.row;
        detailAddress = [app.wallet getReceiveAddressForAccount:row];
        self.clickedAddress = detailAddress;
        clickedAccount = row;
        
        detailLabel = [app.wallet getLabelForAccount:row];
    }
    else {
        detailAddress = [self getAddress:[_tableView indexPathForSelectedRow]];
        NSString *addr = detailAddress;
        NSString *label = [app.wallet labelForLegacyAddress:addr];
        
        self.clickedAddress = addr;
        
        if (label.length > 0)
            detailLabel = label;
        else
            detailLabel = addr;
    }
    optionsTitleLabel.text = detailLabel;
    
    [app showModalWithContent:requestCoinsView closeType:ModalCloseTypeClose headerText:BC_STRING_REQUEST_AMOUNT onDismiss:^() {
        // Remove the extra menu item (more actions)
        [moreActionsButton removeFromSuperview];
        moreActionsButton.alpha = 0.0f;
    } onResume:^() {
        // Reset the requested amount when showing the request screen
        requestAmountTextField.text = nil;
        
        // Show an extra menu item (more actions)
        [app.modalView addSubview:moreActionsButton];
        [UIView animateWithDuration:ANIMATION_DURATION animations:^{
            moreActionsButton.alpha = 1.0f;
        }];
    }];
    
    [self setQRPayment];

    requestAmountTextField.inputAccessoryView = amountKeyboardAccessoryView;
    
    requestAmountTextField.hidden = YES;
    [requestAmountTextField becomeFirstResponder];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        return 44.0f;
    }
    
    return 70.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
#ifndef ENABLE_MULTIPLE_ACCOUNTS
    if (section == 0) {
        return 12;
    }
#endif
    return 45.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 45)];
    view.backgroundColor = [UIColor whiteColor];
    
#ifndef ENABLE_MULTIPLE_ACCOUNTS
    if (section == 0) {
        return view;
    }
#endif
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, self.view.frame.size.width, 14)];
    label.textColor = COLOR_FOREGROUND_GRAY;
    label.font = [UIFont systemFontOfSize:14.0];
    
    [view addSubview:label];
    
    NSString *labelString;
    
    if (section == 0)
        labelString = BC_STRING_MY_ACCOUNTS;
    else if (section == 1) {
        labelString = BC_STRING_IMPORTED_ADDRESSES;
        
        UIButton *addButton = [[UIButton alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 20 - 20, 14, 25, 25)];
        [addButton setImage:[UIImage imageNamed:@"new-grey"] forState:UIControlStateNormal];
        [addButton addTarget:self action:@selector(scanKeyClicked:) forControlEvents:UIControlEventTouchUpInside];
        [view addSubview:addButton];
    }
    else if (section == 2)
        labelString = BC_STRING_IMPORTED_ADDRESSES_ARCHIVED;
    else
        @throw @"Unknown Section";
    
    label.text = [labelString uppercaseString];
    
    return view;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
        return [app.wallet getAccountsCount];
    else if (section == 1)
        return [activeKeys count];
    else
        return [archivedKeys count];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    int n = 2;
    
    if ([archivedKeys count]) ++n;
    
    return n;
}

- (UITableViewCell *)tableView:(UITableView *)_tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        int accountIndex = (int) indexPath.row;
        NSString *accountLabelString = [app.wallet getLabelForAccount:accountIndex];
        
        ReceiveTableCell *cell = [tableView dequeueReusableCellWithIdentifier:@"receiveAccount"];
        
        if (cell == nil) {
            cell = [[[NSBundle mainBundle] loadNibNamed:@"ReceiveCell" owner:nil options:nil] objectAtIndex:0];
            cell.backgroundColor = COLOR_BACKGROUND_GRAY;
        
            // Don't show the watch only tag and resize the label and balance labels to use up the freed up space
            cell.labelLabel.frame = CGRectMake(20, 11, 185, 21);
            cell.balanceLabel.frame = CGRectMake(217, 11, 120, 21);
            [cell.watchLabel setHidden:TRUE];
        }
        
        cell.labelLabel.text = accountLabelString;
        cell.addressLabel.text = @"";
        
        uint64_t balance = [app.wallet getBalanceForAccount:accountIndex];
        
        // Selected cell color
        UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0,0,cell.frame.size.width,cell.frame.size.height)];
        [v setBackgroundColor:COLOR_BLOCKCHAIN_BLUE];
        [cell setSelectedBackgroundView:v];
        
        cell.balanceLabel.text = [app formatMoney:balance];
        
        return cell;
    }
    
    NSString *addr = [self getAddress:indexPath];
    
    Boolean isWatchOnlyLegacyAddress = [app.wallet isWatchOnlyLegacyAddress:addr];
    
    ReceiveTableCell *cell;
    if (isWatchOnlyLegacyAddress) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"receiveWatchOnly"];
    }
    else {
        cell = [tableView dequeueReusableCellWithIdentifier:@"receiveNormal"];
    }
    
    if (cell == nil) {
        cell = [[[NSBundle mainBundle] loadNibNamed:@"ReceiveCell" owner:nil options:nil] objectAtIndex:0];
        cell.backgroundColor = COLOR_BACKGROUND_GRAY;
        
        if (isWatchOnlyLegacyAddress) {
            // Show the watch only tag and resize the label and balance labels so there is enough space
            cell.labelLabel.frame = CGRectMake(20, 11, 148, 21);
            
            cell.balanceLabel.frame = CGRectMake(254, 11, 83, 21);
            
            [cell.watchLabel setHidden:FALSE];
        }
        else {
            // Don't show the watch only tag and resize the label and balance labels to use up the freed up space
            cell.labelLabel.frame = CGRectMake(20, 11, 185, 21);
            
            cell.balanceLabel.frame = CGRectMake(217, 11, 120, 21);
            
            [cell.watchLabel setHidden:TRUE];
        }
    }
    
    NSString *label =  [app.wallet labelForLegacyAddress:addr];
    
    if (label)
        cell.labelLabel.text = label;
    else
        cell.labelLabel.text = BC_STRING_NO_LABEL;
    
    cell.addressLabel.text = addr;
    
    uint64_t balance = [app.wallet getLegacyAddressBalance:addr];
    
    // Selected cell color
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0,0,cell.frame.size.width,cell.frame.size.height)];
    [v setBackgroundColor:COLOR_BLOCKCHAIN_BLUE];
    [cell setSelectedBackgroundView:v];
    
    cell.balanceLabel.text = [app formatMoney:balance];
    
    return cell;
}

@end
