//
//  PrgPopoverBackgroundView.m
//  harmony
//
//  Created by Yujiro Miyabayashi on 13/01/28.
//  Copyright (c) 2013年 Yujiro Miyabayashi. All rights reserved.
//

#import "PopoverBackgroundView.h"

#define CONTENT_INSET 10.0 
#define CAP_INSET 25.0 
#define ARROW_BASE 25.0 
#define ARROW_HEIGHT 25.0


@implementation PopoverBackgroundView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor=[UIColor blackColor];
        // Initialization code
    }
    return self;
}

- (CGFloat) arrowOffset { return _arrowOffset; }
- (void) setArrowOffset:(CGFloat)arrowOffset { _arrowOffset = arrowOffset; }
- (UIPopoverArrowDirection)arrowDirection { return _arrowDirection; }
- (void)setArrowDirection:(UIPopoverArrowDirection)arrowDirection { _arrowDirection = arrowDirection; }

+(UIEdgeInsets)contentViewInsets{
    return UIEdgeInsetsMake(CONTENT_INSET, CONTENT_INSET, CONTENT_INSET, CONTENT_INSET);
}

+(CGFloat)arrowHeight{ return ARROW_HEIGHT; }
+(CGFloat)arrowBase{ return ARROW_BASE; }



/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
