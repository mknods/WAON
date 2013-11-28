//
//  UIShadowLabel.h
//  waon
//
//  Created by Yujiro Miyabayashi on 11/20/13.
//  Copyright (c) 2013 Yujiro Miyabayashi. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIShadowLabel : UILabel{

    UIFont* font;
    UIColor* text_color;
}
@property (nonatomic) UIFont* font;
@property (nonatomic) UIColor* text_color;

@end
