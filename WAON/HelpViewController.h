//
//  HelpViewController.h
//  harmony
//
//  Created by Yujiro Miyabayashi on 13/02/14.
//  Copyright (c) 2013年 Yujiro Miyabayashi. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HelpViewController : UIViewController <UIScrollViewDelegate>
{
    UIView* bg_plate;
    UIImage* img_item[5];
    UIScrollView* scroll_view;
    UIImageView* img_app;
    
    UIButton* btn_close;
    id parent_vc;
}

-(id) initWithFrame:(CGRect)frame;
-(void) setInstance:(id)parent;

@end
