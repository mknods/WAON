//
//  PopoverBackgroundView.h
//  harmony
//
//  Created by Yujiro Miyabayashi on 13/01/28.
//  Copyright (c) 2013年 Yujiro Miyabayashi. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PopoverBackgroundView : UIPopoverBackgroundView
{
    UIImageView *_borderImageView;
    UIImageView *_arrowView;
    CGFloat _arrowOffset;
    UIPopoverArrowDirection _arrowDirection;

}
@end
