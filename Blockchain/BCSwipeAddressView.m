//
//  BCSwipeAddressView.m
//  Blockchain
//
//  Created by kevinwu on 3/9/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

#import "BCSwipeAddressView.h"
#import "UIView+ChangeFrameAttribute.h"
#import "QRCodeGenerator.h"

@interface BCSwipeAddressView ()
@property (nonatomic) BCSwipeAddressViewModel *viewModel;
@property (nonatomic) UIImageView *qrCodeImageView;
@property (nonatomic) UILabel *addressLabel;
@end

@implementation BCSwipeAddressView

- (id)initWithFrame:(CGRect)frame viewModel:(BCSwipeAddressViewModel *)viewModel
{
    if (self == [super initWithFrame:frame]) {
        self.viewModel = viewModel;
        [self setup];
    }
    return self;
}

- (void)setup
{
    UIImageView *assetImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 100, 80, 80)];
    assetImageView.image = [UIImage imageNamed:@"bitcoin"];
    assetImageView.center = CGPointMake(self.bounds.size.width/2, assetImageView.frame.origin.y);
    [self addSubview:assetImageView];
    
    UIButton *requestButton = [[UIButton alloc] initWithFrame:CGRectMake(0, assetImageView.frame.origin.y + assetImageView.frame.size.height + 30, 0, 0)];
    requestButton.titleLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_LIGHT size:FONT_SIZE_SMALL];
    CGFloat horizontalPadding = 12;
    requestButton.titleEdgeInsets = UIEdgeInsetsMake(0, horizontalPadding, 0, horizontalPadding);
    [requestButton setTitle:self.viewModel.action forState:UIControlStateNormal];
    [requestButton sizeToFit];
    [requestButton changeWidth:requestButton.frame.size.width + horizontalPadding*2];
    [requestButton changeHeight:40];
    [requestButton setTitleColor:COLOR_BLOCKCHAIN_LIGHT_BLUE forState:UIControlStateNormal];
    requestButton.backgroundColor = COLOR_BLOCKCHAIN_LIGHTEST_BLUE;
    requestButton.center = CGPointMake(self.bounds.size.width/2, requestButton.center.y);
    requestButton.layer.cornerRadius = 8;
    [self addSubview:requestButton];
    
    CGFloat addressLabelHeight = 30;
    CGFloat addressLabelPadding = 10;
    UILabel *addressLabel = [[UILabel alloc] initWithFrame:CGRectMake(addressLabelPadding, self.bounds.size.height - 30 - addressLabelHeight, self.bounds.size.width - addressLabelPadding*2, addressLabelHeight)];
    [addressLabel setTextAlignment:NSTextAlignmentCenter];
    [addressLabel setTextColor:COLOR_TEXT_DARK_GRAY];
    [addressLabel setFont:[UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_EXTRA_SMALL]];
    addressLabel.adjustsFontSizeToFitWidth = YES;
    [self addSubview:addressLabel];
    self.addressLabel = addressLabel;
    
    CGFloat qrCodeWidth = self.bounds.size.width*2/3;
    UIImageView *qrCodeImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, addressLabel.frame.origin.y - 16 - qrCodeWidth, qrCodeWidth, qrCodeWidth)];
    qrCodeImageView.center = CGPointMake(self.bounds.size.width/2, qrCodeImageView.center.y);
    [self addSubview:qrCodeImageView];
    self.qrCodeImageView = qrCodeImageView;
}

- (void)setViewModel:(BCSwipeAddressViewModel *)viewModel
{
    _viewModel = viewModel;
    
    [self updateQRCode];
}

- (void)updateAddress:(NSString *)address
{
    self.viewModel.address = address;
    
    [self updateQRCode];
}

- (void)updateQRCode
{
    NSString *address = self.viewModel.address;
    if ([address isEqualToString:BC_STRING_REQUEST_FAILED_PLEASE_CHECK_INTERNET_CONNECTION]) {
        self.qrCodeImageView.hidden = YES;
        self.addressLabel.text = address;
    } else if (address) {
        QRCodeGenerator *qrCodeGenerator = [[QRCodeGenerator alloc] init];
        self.qrCodeImageView.image = [qrCodeGenerator qrImageFromAddress:address];
        self.addressLabel.text = address;
    } else {
        self.qrCodeImageView.hidden = YES;
        self.addressLabel.text = BC_STRING_PLEASE_LOGIN_TO_LOAD_MORE_ADDRESSES;
    }
}

@end
