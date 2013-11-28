//
//  InfoViewController.h
//  harmony
//
//  Created by Yujiro Miyabayashi on 13/02/14.
//  Copyright (c) 2013年 Yujiro Miyabayashi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>


@interface InfoViewController : UIViewController
{
    UIButton* btn_close;
    UIImageView* img_text;
    id parent_vc;
}

-(id) initWithFrame:(CGRect)frame;
-(void) setInstance:(id)parent;

@end
