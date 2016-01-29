//
//  QRCodeGenerator.h
//  Blockchain
//
//  Created by Kevin Wu on 1/29/16.
//  Copyright © 2016 Qkos Services Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QRCodeGenerator : NSObject
- (UIImage *)qrImageFromAddress:(NSString *)address;
- (UIImage *)qrImageFromAddress:(NSString *)address amount:(double)amount;
@end
