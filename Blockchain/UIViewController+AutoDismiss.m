//
//  UIViewController+AutoDismiss.m
//  Blockchain
//
//  Created by Kevin Wu on 10/1/15.
//  Copyright © 2015 Qkos Services Ltd. All rights reserved.
//

#import "UIViewController+AutoDismiss.h"

@implementation UIViewController (AutoDismiss)

- (void)autoDismiss
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self dismissViewControllerAnimated:YES completion:nil];
    
    // Special case for UIActivityViewController, when tapping more actions shows another viewController
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
