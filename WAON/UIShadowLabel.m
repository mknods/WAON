//
//  UIShadowLabel.m
//  waon
//
//  Created by Yujiro Miyabayashi on 11/20/13.
//  Copyright (c) 2013 Yujiro Miyabayashi. All rights reserved.
//

#import "UIShadowLabel.h"

@implementation UIShadowLabel



- (void)drawRect:(CGRect)rect
{
    　CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGColorRef glowColor = CGColorCreateCopyWithAlpha([[UIColor colorWithRed:0.9f green:0.9f blue:0.9f alpha:1.0f] CGColor], 1.f);
//    CGColorRef glowColor = [[UIColor colorWithRed:0.9f green:0.9f blue:0.9f alpha:1.0f] CGColor];

//    CGColorRef glowColor = [[UIColor whiteColor] CGColor];
    
    [self.text_color set];
    self.textColor = self.text_color;
    
    CGContextSetShadowWithColor( context, CGSizeMake( 0.0, -1.0 ), 6.0f, glowColor );
//    CGColorRelease(glowColor);
    
    self.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    
   　NSString *disp = [NSString stringWithString: self.text];
//    [disp drawAtPoint:CGPointMake(0.0f, 0.0f) withFont:self.font];

//    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
//    [style setAlignment:NSTextAlignmentCenter];
    
//    NSFont *font = font;
//    NSDictionary *attrsDictionary = [NSDictionary dictionaryWithObject:font
//                                                                forKey:NSFontAttributeName];
    
//    NSAttributedString *str = [[NSAttributedString alloc] initWithString:self.text
//                                                              attributes:@{NSForegroundColorAttributeName : self.textColor,
//                                                                           NSParagraphStyleAttributeName:style}];

//    self.textAlignment = NSTextAlignmentCenter;
//    self.attributedText = str;
//    [str drawInRect:CGRectMake(0, 10, 35, 30)];
    [disp drawInRect:self.bounds
            withFont:self.font
       lineBreakMode:UILineBreakModeClip
           alignment:NSTextAlignmentCenter];
//    [disp drawInRect:self.bounds];
    
}
@end

