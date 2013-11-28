//
//  HelpViewController.m
//  harmony
//
//  Created by Yujiro Miyabayashi on 13/02/14.
//  Copyright (c) 2013年 Yujiro Miyabayashi. All rights reserved.
//

#import "HelpViewController.h"
#import "MainViewController.h"

@interface HelpViewController ()

@end



@implementation HelpViewController

int page_w = 1024-400;
int page_h = 768-100-200;


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
    
    
    

    scroll_view = [[UIScrollView alloc] initWithFrame:CGRectMake(400, 200, page_w, page_h)];

    scroll_view.scrollEnabled = YES;
    scroll_view.delaysContentTouches=NO;    // << touch遅延原因
    scroll_view.bounces = YES;
    scroll_view.pagingEnabled = YES;
    scroll_view.indicatorStyle=UIScrollViewIndicatorStyleWhite;
    scroll_view.contentSize = CGSizeMake(220, page_h*5);
    scroll_view.delegate=self;
    
    [self.view addSubview:scroll_view];
    
    
    
    UIImageView* howto_txt[5];
    howto_txt[0] = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"howto_txt_1"]];
    howto_txt[1] = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"howto_txt_2"]];
    howto_txt[2] = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"howto_txt_3"]];
    howto_txt[3] = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"howto_txt_4"]];
    howto_txt[4] = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"howto_txt_5"]];

    [howto_txt[0] setFrame:CGRectMake(0,0,550,478/2)];
    [howto_txt[1] setFrame:CGRectMake(0,page_h,550,514/2)];
    [howto_txt[2] setFrame:CGRectMake(0,page_h*2,550,800/2)];
    [howto_txt[3] setFrame:CGRectMake(0,page_h*3,550,837/2)];
    [howto_txt[4] setFrame:CGRectMake(0,page_h*4,550,790/2)];

    [scroll_view addSubview:howto_txt[0]];
    [scroll_view addSubview:howto_txt[1]];
    [scroll_view addSubview:howto_txt[2]];
    [scroll_view addSubview:howto_txt[3]];
    [scroll_view addSubview:howto_txt[4]];

    
    img_item[0] = [UIImage imageNamed:@"help1"];
    img_item[1] = [UIImage imageNamed:@"help2"];
    img_item[2] = [UIImage imageNamed:@"help3"];
    img_item[3] = [UIImage imageNamed:@"help_appendix"];

    img_app =[[UIImageView alloc]initWithImage:img_item[0]];
    [img_app setFrame:CGRectMake(50,180 ,351,278)];
    [self.view addSubview:img_app];
    
    UIImageView* title = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"howto_title"]];
    [title setFrame:CGRectMake(1024/2-50,0,100,124)];
    [self.view addSubview:title];
    
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
    
    [(MainViewController*)parent_vc close_help];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

-(void) endScroll{
    
    // フリック操作によるスクロール終了
    if(scroll_view.contentOffset.y < page_h){
        
        img_app.image = img_item[0];
        
    }else if(scroll_view.contentOffset.y < page_h*2){
        
        img_app.image = img_item[1];
        
    }else if(scroll_view.contentOffset.y < page_h*3){
        
        img_app.image = img_item[2];
        
    }else{
        
        img_app.image = img_item[3];
        
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {

	[self endScroll];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [self endScroll];

}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
  
    
}

@end
