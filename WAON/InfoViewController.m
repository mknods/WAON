//
//  InfoViewController.m
//  harmony
//
//  Created by Yujiro Miyabayashi on 13/02/14.
//  Copyright (c) 2013年 Yujiro Miyabayashi. All rights reserved.
//

#import "InfoViewController.h"
#import "MainViewController.h"

@interface InfoViewController ()

@end

@implementation InfoViewController

-(id)initWithFrame:(CGRect)frame{

    self = [super init];
    if (self) {

        self.view.frame = frame;
        self.view.backgroundColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.8f];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    UIImage *image = [UIImage imageNamed:@"info_text.png"];
    img_text = [[UIImageView alloc] initWithImage:image];
    img_text.frame =CGRectMake(0,0,201,287);
    img_text.center = CGPointMake(1024/2,768/2);
    [self.view addSubview:img_text];
    
    //CLOSE BUTTON
    btn_close = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    btn_close.frame = CGRectMake( 1024-57, 0, 57,57);
    [btn_close setBackgroundImage:[UIImage imageNamed:@"info_close"] forState:UIControlStateNormal];
    [btn_close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn_close];
}

-(void)setInstance:(id)parent{
    
    parent_vc = parent;
}

-(void)close{
    
    [(MainViewController*)parent_vc close_info];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
