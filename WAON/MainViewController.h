//
//  MainViewController.h
//  harmony
//
//  Created by Yujiro Miyabayashi on 12/09/26.
//  Copyright (c) 2012年 Yujiro Miyabayashi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenAL/al.h>
#import <OpenAL/alc.h>
#import <AudioToolbox/AudioToolbox.h>

#import "HelpViewController.h"
#import "InfoViewController.h"

#import "UIShadowLabel.h"


#define KEY_NUM   (12*3) //(88)
#define PITCH_NUM  (12*5)

#define TEMPO_UP    0
#define TEMPO_DOWN  1
#define TEMPO_START 2

#define SLIDER_VOL_4    0
#define SLIDER_VOL_8    1
#define SLIDER_VOL_16   2
#define SLIDER_VOL_3    3
#define SLIDER_VOL_ALL  4


@interface MainViewController : UIViewController  <UIScrollViewDelegate>
{
   
    ALuint  key_buffers[PITCH_NUM];
    ALuint  key_sources[PITCH_NUM];
    ALfloat key_pitch[PITCH_NUM];

    UIButton* btn_key[KEY_NUM];

    UIShadowLabel *lbl_key[12];
    UIShadowLabel *lbl_pitch[12];
    UIImageView *key_bg[12];
    
    UIButton *btn_up[12];
    UIButton *btn_down[12];

    UIButton *btn_pitch[4];
    bool btn_selected[4];
    
    UIButton *btn_hz_up;
    UIButton *btn_hz_down;
    UIShadowLabel* lbl_hz;
    int pitch_val;

    UIImageView* top_bg;
    
    //MENU
    UIButton *btn_menu[2];
    HelpViewController* help_vc;
    InfoViewController* info_vc;
    
    //METRONOME
    ALuint  _buffers[4];
    ALuint  _sources[4];

    ALuint  click_buffer;
    ALuint  click_source;

    
    UIShadowLabel *lbl_tempo;
    
    UIButton *btn_tempo[3];
    UISlider* slider_vol[5];

    NSString* str_key;
    
    NSInteger pitch_mode;
    
}

@property (strong, nonatomic) UIPopoverController *popOver;

-(id)initWithFrame:(CGRect)frame;
-(void)translate:(int)key: (NSString*)item_name;
-(void)close_info;
-(void)close_help;


@end
