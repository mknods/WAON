//
//  MainViewController.m
//  harmony
//
//  Created by Yujiro Miyabayashi on 12/09/26.
//  Copyright (c) 2012年 Yujiro Miyabayashi. All rights reserved.
//

#import "MainViewController.h"
#import <QuartzCore/QuartzCore.h>

#define EQUAL_TEMPERATE (0)
#define JYUNSEI_MAJOR   (1)
#define JYUNSEI_MINOR   (2)

@interface MainViewController ()

@end



void* GetOpenALAudioData(
                         CFURLRef fileURL, ALsizei* dataSize, ALenum* dataFormat, ALsizei *sampleRate)
{
    OSStatus    err;
    UInt32      size;
    
    // オーディオファイルを開く
    ExtAudioFileRef audioFile;
    err = ExtAudioFileOpenURL(fileURL, &audioFile);
    if (err) {
        goto Exit;
    }
    
    // オーディオデータフォーマットを取得する
    AudioStreamBasicDescription fileFormat;
    size = sizeof(fileFormat);
    err = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileDataFormat, &size, &fileFormat);
    if (err) {
        goto Exit;
    }
    
    // アウトプットフォーマットを設定する
    AudioStreamBasicDescription outputFormat;
    outputFormat.mSampleRate = fileFormat.mSampleRate;
    outputFormat.mChannelsPerFrame = fileFormat.mChannelsPerFrame;
    outputFormat.mFormatID = kAudioFormatLinearPCM;
    outputFormat.mBytesPerPacket = 2 * outputFormat.mChannelsPerFrame;
    outputFormat.mFramesPerPacket = 1;
    outputFormat.mBytesPerFrame = 2 * outputFormat.mChannelsPerFrame;
    outputFormat.mBitsPerChannel = 16;
    outputFormat.mFormatFlags = kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
    err = ExtAudioFileSetProperty(
                                  audioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(outputFormat), &outputFormat);
    if (err) {
        goto Exit;
    }
    
    // フレーム数を取得する
    SInt64  fileLengthFrames = 0;
    size = sizeof(fileLengthFrames);
    err = ExtAudioFileGetProperty(
                                  audioFile, kExtAudioFileProperty_FileLengthFrames, &size, &fileLengthFrames);
    if (err) {
        goto Exit;
    }
    
    // バッファを用意する
    UInt32          bufferSize;
    void*           data;
    AudioBufferList dataBuffer;
    bufferSize = fileLengthFrames * outputFormat.mBytesPerFrame;;
    data = malloc(bufferSize);
    dataBuffer.mNumberBuffers = 1;
    dataBuffer.mBuffers[0].mDataByteSize = bufferSize;
    dataBuffer.mBuffers[0].mNumberChannels = outputFormat.mChannelsPerFrame;
    dataBuffer.mBuffers[0].mData = data;
    
    // バッファにデータを読み込む
    err = ExtAudioFileRead(audioFile, (UInt32*)&fileLengthFrames, &dataBuffer);
    if (err) {
        free(data);
        goto Exit;
    }
    
    // 出力値を設定する
    *dataSize = (ALsizei)bufferSize;
    *dataFormat = (outputFormat.mChannelsPerFrame > 1) ? AL_FORMAT_STEREO16 : AL_FORMAT_MONO16;
    *sampleRate = (ALsizei)outputFormat.mSampleRate;
    
Exit:
    // オーディオファイルを破棄する
    if (audioFile) {
        ExtAudioFileDispose(audioFile);
    }
    
    return data;
}





@implementation MainViewController


ALCcontext* alContext;
ALCdevice*  device;



//METRONOME
static float tempo = 60.0f/120;
static bool is_running = NO;
NSTimer *timer_tempo;
NSTimer *timer_tempo_3;
NSTimer *timer_tempo_longpress;
static int count_16 = 0;
static int count_3ren = 0;
NSOperationQueue *opque;

UILongPressGestureRecognizer *gesture_tempo_up;
UILongPressGestureRecognizer *gesture_tempo_down;

UILongPressGestureRecognizer *long_press_up[KEY_NUM];
UILongPressGestureRecognizer *long_press_down[KEY_NUM];


#define MAJOR 0
#define MINOR 1

int mode=MAJOR;
int base_key = 12*3-3;//12*2-3;

#define POW_2 (1.0594630943593f)    //pow(2, 1/12)
#define POW_1CENT   (1.00057778950655f)

float pitch[KEY_NUM];


float major_pitch[]={
    0.0f,
    -29.3f,
    3.9f,
    15.6f,
    -13.7f,
    -2.0f,
    -31.3f,
    2.0f,
    -27.4f,
    -15.6f,
    17.9f,
    -11.7f
};


float minor_pitch[]={
    0.0f,
    33.2f,
    3.9f,
    15.6f,
    -13.7f,
    -2.0f,
    31.3f,
    2.0f,
    13.7f,
    -15.6f,
    17.6f,
    -11.7f
};


#define APP_STATE_INIT 1
#define APP_STATE_RUN  2
static int APP_STATE = APP_STATE_RUN;

-(void)init_all{
   
    btn_hz_up.enabled = NO;
    btn_hz_down.enabled = NO;
    
    if( APP_STATE == APP_STATE_RUN){
    
        APP_STATE = APP_STATE_INIT;

        //KEY
        [self set_base_hz :pitch_val];
        [self change_mode: pitch_mode:0];
        [self set_volume: slider_vol[SLIDER_VOL_ALL]];
        
        //--------------------------
        //METRONOME
        //--------------------------
        [self init_sounds];

        APP_STATE = APP_STATE_RUN;
    }
    btn_hz_up.enabled = YES;
    btn_hz_down.enabled = YES;
    
    
    [self translate:0: @"C" ];

    [self initClickSound];
}

-(id)initWithFrame:(CGRect)frame{
    
    self = [super init];
    if (self) {
        self.view.frame = frame;
    }
    return self;
}


- (void)viewWillDisapper{
    
    for(int i=0; i<KEY_NUM; i++){
        alSourceStop(key_sources[i]);
    }
}

-(void)stopSoundAll{
    
    for(int i=0; i<KEY_NUM; i++){
        [self stopSound:btn_key[i]];
    }
}


-(void)selSwipeGesture:(UISwipeGestureRecognizer *)sender {

    for(int i=0; i<KEY_NUM; i++){
        alSourceStop(key_sources[i]);
    }
}

- (void)viewDidLoad
{
//    UISwipeGestureRecognizer* swipe_r = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(selSwipeGesture:)];
//    UISwipeGestureRecognizer* swipe_l = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(selSwipeGesture:)];
//    UISwipeGestureRecognizer* swipe_up = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(selSwipeGesture:)];
//    UISwipeGestureRecognizer* swipe_down = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(selSwipeGesture:)];
//    swipe_r.direction = UISwipeGestureRecognizerDirectionRight;
//    swipe_l.direction = UISwipeGestureRecognizerDirectionLeft;
//    swipe_up.direction = UISwipeGestureRecognizerDirectionUp;
//    swipe_down.direction = UISwipeGestureRecognizerDirectionDown;
//
//    [self.view addGestureRecognizer:swipe_r];
//    [self.view addGestureRecognizer:swipe_l];
//    [self.view addGestureRecognizer:swipe_up];
//    [self.view addGestureRecognizer:swipe_down];
    
    int screenW = [[UIScreen mainScreen] applicationFrame].size.width;
    int screenH = [[UIScreen mainScreen] applicationFrame].size.height;

    int white_w = 185/2; //94;
    int white_h = 834/2;//415;
    int blk_w = 104/2;//55;
    int blk_h = 260;

    //文字色
    UIColor* text_color = [UIColor colorWithRed:206/255.f green:200/255.f blue:188/255.f alpha:1.f];
    self.view.backgroundColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.f];

    /* key */
    CGRect rect = CGRectMake(0, 336, 1024,screenW-300 );
    UIScrollView *scroll_view = [[UIScrollView alloc] initWithFrame:rect];
    scroll_view.scrollEnabled = YES;
    scroll_view.canCancelContentTouches = NO;
    scroll_view.delaysContentTouches=NO;    // << touch遅延原因
    scroll_view.alwaysBounceHorizontal = TRUE;
    scroll_view.bounces = YES;
    scroll_view.showsHorizontalScrollIndicator = TRUE;
    scroll_view.pagingEnabled=NO;
    scroll_view.indicatorStyle=UIScrollViewIndicatorStyleWhite;
    scroll_view.contentSize = CGSizeMake(white_w*7*3, 0);
    scroll_view.backgroundColor=[UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:1];
    scroll_view.delegate = self;
    
    [self.view addSubview:scroll_view];

    for(int i=0; i<KEY_NUM; i++){

        btn_key[i] = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn_key[i] addTarget:self action:@selector(playSound:) forControlEvents:UIControlEventTouchDown];
        [btn_key[i] addTarget:self action:@selector(stopSound:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
        
        btn_key[i].tag = i;
    }
    
    
    
    int pos = 0;
    int offset =0;
    int top_pos = 0;
    
    for(int j=0; j<KEY_NUM/12; j++){

        // OFF
        [btn_key[pos+0] setBackgroundImage:[UIImage imageNamed:@"key_c"] forState:UIControlStateNormal];
        [btn_key[pos+1] setBackgroundImage:[UIImage imageNamed:@"key_cis"] forState:UIControlStateNormal];
        [btn_key[pos+2] setBackgroundImage:[UIImage imageNamed:@"key_d"] forState:UIControlStateNormal];
        [btn_key[pos+3] setBackgroundImage:[UIImage imageNamed:@"key_dis"] forState:UIControlStateNormal];
        [btn_key[pos+4] setBackgroundImage:[UIImage imageNamed:@"key_e"] forState:UIControlStateNormal];
        [btn_key[pos+5] setBackgroundImage:[UIImage imageNamed:@"key_f"] forState:UIControlStateNormal];
        [btn_key[pos+6] setBackgroundImage:[UIImage imageNamed:@"key_fis"] forState:UIControlStateNormal];
        [btn_key[pos+7] setBackgroundImage:[UIImage imageNamed:@"key_g"] forState:UIControlStateNormal];
        [btn_key[pos+8] setBackgroundImage:[UIImage imageNamed:@"key_gis"] forState:UIControlStateNormal];
        [btn_key[pos+9] setBackgroundImage:[UIImage imageNamed:@"key_a"] forState:UIControlStateNormal];
        [btn_key[pos+10] setBackgroundImage:[UIImage imageNamed:@"key_b"] forState:UIControlStateNormal];
        [btn_key[pos+11] setBackgroundImage:[UIImage imageNamed:@"key_h"] forState:UIControlStateNormal];
        
        // ON
        [btn_key[pos+0] setBackgroundImage:[UIImage imageNamed:@"key_c_on"] forState:UIControlStateHighlighted];
        [btn_key[pos+1] setBackgroundImage:[UIImage imageNamed:@"key_cis_on"] forState:UIControlStateHighlighted];
        [btn_key[pos+2] setBackgroundImage:[UIImage imageNamed:@"key_d_on"] forState:UIControlStateHighlighted];
        [btn_key[pos+3] setBackgroundImage:[UIImage imageNamed:@"key_dis_on"] forState:UIControlStateHighlighted];
        [btn_key[pos+4] setBackgroundImage:[UIImage imageNamed:@"key_e_on"] forState:UIControlStateHighlighted];
        [btn_key[pos+5] setBackgroundImage:[UIImage imageNamed:@"key_f_on"] forState:UIControlStateHighlighted];
        [btn_key[pos+6] setBackgroundImage:[UIImage imageNamed:@"key_fis_on"] forState:UIControlStateHighlighted];
        [btn_key[pos+7] setBackgroundImage:[UIImage imageNamed:@"key_g_on"] forState:UIControlStateHighlighted];
        [btn_key[pos+8] setBackgroundImage:[UIImage imageNamed:@"key_gis_on"] forState:UIControlStateHighlighted];
        [btn_key[pos+9] setBackgroundImage:[UIImage imageNamed:@"key_a_on"] forState:UIControlStateHighlighted];
        [btn_key[pos+10] setBackgroundImage:[UIImage imageNamed:@"key_b_on"] forState:UIControlStateHighlighted];
        [btn_key[pos+11] setBackgroundImage:[UIImage imageNamed:@"key_h_on"] forState:UIControlStateHighlighted];

        [btn_key[pos+0] setFrame:CGRectMake( offset + white_w * 0,      top_pos, white_w, white_h)];
        [btn_key[pos+1] setFrame:CGRectMake( offset + white_w * 0 + 57, top_pos, blk_w, blk_h)];
        [btn_key[pos+2] setFrame:CGRectMake( offset + white_w * 1,      top_pos, white_w, white_h)];
        [btn_key[pos+3] setFrame:CGRectMake( offset + white_w * 2 - 14, top_pos, blk_w, blk_h)];
        [btn_key[pos+4] setFrame:CGRectMake( offset + white_w * 2,      top_pos, white_w, white_h)];
        [btn_key[pos+5] setFrame:CGRectMake( offset + white_w * 3,      top_pos, white_w, white_h)];
        [btn_key[pos+6] setFrame:CGRectMake( offset + white_w * 3 + 52, top_pos, blk_w, blk_h)];
        [btn_key[pos+7] setFrame:CGRectMake( offset + white_w * 4,      top_pos, white_w, white_h)];
        [btn_key[pos+8] setFrame:CGRectMake( offset + white_w * 5-(blk_w/2)+1, top_pos, blk_w, blk_h)];
        [btn_key[pos+9] setFrame:CGRectMake( offset + white_w * 5,           top_pos, white_w, white_h)];
        [btn_key[pos+10] setFrame:CGRectMake( offset + white_w * 6 - 8, top_pos, blk_w, blk_h)];
        [btn_key[pos+11] setFrame:CGRectMake( offset + white_w * 6,     top_pos, white_w, white_h)];
        
        
        //白鍵
        [scroll_view addSubview:btn_key[pos+0]];
        [scroll_view addSubview:btn_key[pos+2]];
        [scroll_view addSubview:btn_key[pos+4]];
        [scroll_view addSubview:btn_key[pos+5]];
        [scroll_view addSubview:btn_key[pos+7]];
        [scroll_view addSubview:btn_key[pos+9]];
        [scroll_view addSubview:btn_key[pos+11]];
        //黒鍵
        [scroll_view addSubview:btn_key[pos+1]];
        [scroll_view addSubview:btn_key[pos+3]];
        [scroll_view addSubview:btn_key[pos+6]];
        [scroll_view addSubview:btn_key[pos+8]];
        [scroll_view addSubview:btn_key[pos+10]];
        
        pos+=12;
        offset += white_w*7+1;
    }
    
    
    //TOP Background
    top_bg = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"top_bg"]];
    [top_bg setFrame:CGRectMake(0, 0, 1024, 339)];
    [top_bg setContentMode:UIViewContentModeScaleToFill];
    [self.view addSubview:top_bg];

    //PITCH変更
    // 平均律
    // major or minor
    for(int i=0;i<3;i++){
        
        btn_selected[i] = NO;
        btn_pitch[i] = [UIButton buttonWithType:UIButtonTypeCustom];

        [btn_pitch[i] addTarget:self action:@selector(buttonPush:) forControlEvents:UIControlEventTouchUpInside];
        btn_pitch[i].tag=i;
        
        [self.view addSubview:btn_pitch[i]];
    }
   
    btn_pitch[0].frame = CGRectMake(18,  22, 70, 77);
    btn_pitch[1].frame = CGRectMake(162, 22, 70, 77);
    btn_pitch[2].frame = CGRectMake(232, 22, 70, 77);
    
    [btn_pitch[0] setBackgroundImage:[UIImage imageNamed:@"bt_on"] forState:UIControlStateNormal];
    [btn_pitch[1] setBackgroundImage:[UIImage imageNamed:@"bt_off"] forState:UIControlStateNormal];
    [btn_pitch[2] setBackgroundImage:[UIImage imageNamed:@"bt_off"] forState:UIControlStateNormal];
    [btn_pitch[0] setBackgroundImage:[UIImage imageNamed:@"bt_active"] forState:UIControlStateHighlighted];
    [btn_pitch[1] setBackgroundImage:[UIImage imageNamed:@"bt_active"] forState:UIControlStateHighlighted];
    [btn_pitch[2] setBackgroundImage:[UIImage imageNamed:@"bt_active"] forState:UIControlStateHighlighted];
    
    // 442Hz
    lbl_hz = [[UIShadowLabel alloc]initWithFrame:CGRectMake(383,47,90,32)];
    pitch_val = 442;
    lbl_hz.text = @"442 Hz";
    lbl_hz.font = [UIFont fontWithName:@"AvenirNextCondensed-Regular" size:24];
    lbl_hz.text_color = [UIColor colorWithRed:199/255.f green:166/255.f blue:144/255.f alpha:1.f];
    lbl_hz.backgroundColor=[UIColor colorWithRed:1.f green:1.f blue:1.f alpha:0.0f];
    [self.view addSubview:lbl_hz];
    
    btn_hz_up = [UIButton buttonWithType:UIButtonTypeCustom];
    btn_hz_up.frame = CGRectMake( 484, 36,45,25);
    [btn_hz_up addTarget:self action:@selector(hz_up:) forControlEvents:UIControlEventTouchDown];
    [btn_hz_up setBackgroundImage:[UIImage imageNamed:@"bt_plus_off"] forState:UIControlStateNormal];
    [self.view addSubview:btn_hz_up];
    
    btn_hz_down = [UIButton buttonWithType:UIButtonTypeCustom];
    btn_hz_down.frame = CGRectMake( 484, 66,45,25);
    [btn_hz_down addTarget:self action:@selector(hz_down:) forControlEvents:UIControlEventTouchDown];
    [btn_hz_down setBackgroundImage:[UIImage imageNamed:@"bt_minus_off"] forState:UIControlStateNormal];
    [self.view addSubview:btn_hz_down];
    
    
    //移調
//    btn_key_select = [[UILabel alloc]initWithFrame:CGRectMake(40, 75, 40, 80)];
//    btn_key_select.text=@"C";
//    btn_key_select.font = [UIFont fontWithName:@"AGARasheeqV.2-Bold" size:26];
//    btn_key_select.tag=1000;
//    btn_key_select.textColor = [UIColor colorWithRed:199/255.f green:166/255.f blue:144/255.f alpha:1.f];
//    btn_key_select.layer.shadowColor = [[UIColor colorWithRed:199/255.f green:166/255.f blue:144/255.f alpha:.9f] CGColor];
//    btn_key_select.layer.shadowRadius = 4.0f;
//    btn_key_select.layer.shadowOpacity = .9;
//    btn_key_select.textAlignment = UITextAlignmentCenter;
//    btn_key_select.layer.shadowOffset = CGSizeZero;
//    btn_key_select.layer.masksToBounds = YES;
//    btn_key_select.backgroundColor=[UIColor colorWithRed:0.f green:0.f blue:0.f alpha:0.f];
//    btn_key_select.userInteractionEnabled = YES;
//
//    [self.view addSubview:btn_key_select];

    
    //ピッチ変更
    offset = 32;

    for(int i=0; i<12; i++){

        //長押し
        long_press_up[i] = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(LongPressedPitch:)];
        long_press_down[i] = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(LongPressedPitch:)];

        
        // PITCH UP
        
        btn_up[i] = [UIButton buttonWithType:UIButtonTypeCustom];
        btn_up[i].frame = CGRectMake(offset+i*49,160,45,25);
        [btn_up[i] addTarget:self action:@selector(pitch_up:) forControlEvents:UIControlEventTouchDown];
        btn_up[i].tag=i;
        [btn_up[i] addGestureRecognizer:long_press_up[i]];
        [btn_up[i] setBackgroundImage:[UIImage imageNamed:@"bt_plus_off"] forState:UIControlStateNormal];
        [btn_up[i] setBackgroundImage:[UIImage imageNamed:@"bt_plus_on"] forState:UIControlStateHighlighted];

        [self.view addSubview:btn_up[i]];

        // KEY ACTIVE背景
        key_bg[i] = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"key_active"]];
        key_bg[i].frame = CGRectMake(offset-6+i*49,185,55,84);
        [self.view addSubview:key_bg[i]];
        
        // 基準KEY変更
        lbl_key[i] = [[UIShadowLabel alloc]initWithFrame:CGRectMake(offset+2+i*49,202,40,60)];
        lbl_key[i].tag=i;
        lbl_key[i].backgroundColor=[UIColor colorWithRed:0 green:0 blue:0 alpha:0.f];
        lbl_key[i].textColor = text_color;
        lbl_key[i].textAlignment = NSTextAlignmentCenter;
        lbl_key[i].userInteractionEnabled = YES;
        lbl_key[i].font = [UIFont fontWithName:@"AGARasheeqV.2-Bold" size:26];
//        lbl_key[i].font = [UIFont fontWithName:@"AvenirNextCondensed-Regular" size:25];
        [self.view addSubview:lbl_key[i]];

        // PICTH LABEL
        lbl_pitch[i] = [[UIShadowLabel alloc]initWithFrame:CGRectMake(offset+2+i*49,232,40,30)];
        lbl_pitch[i].text=@"00.0";
        lbl_pitch[i].font = [UIFont fontWithName:@"Futura-CondensedMedium" size:16];
        lbl_pitch[i].tag=i;
        lbl_pitch[i].textColor = text_color;
        lbl_pitch[i].textAlignment = UITextAlignmentCenter;
        lbl_pitch[i].backgroundColor=[UIColor colorWithRed:0.f green:0.f blue:0.f alpha:0.f];
        lbl_pitch[i].userInteractionEnabled = YES;
        [self.view addSubview:lbl_pitch[i]];
        
        
        // PITCH DOWN
        btn_down[i] = [UIButton buttonWithType:UIButtonTypeCustom];
        btn_down[i].frame = CGRectMake(offset+i*49,270,45,25);
        [btn_down[i] addTarget:self action:@selector(pitch_down:) forControlEvents:UIControlEventTouchDown];
        btn_down[i].tag=i;
        [btn_down[i] addGestureRecognizer:long_press_down[i]];
        [btn_down[i] setBackgroundImage:[UIImage imageNamed:@"bt_minus_off"] forState:UIControlStateNormal];
        [btn_down[i] setBackgroundImage:[UIImage imageNamed:@"bt_minus_on"] forState:UIControlStateHighlighted];

        [self.view addSubview:btn_down[i]];
        
    }
    lbl_key[0].text=@"C";
    lbl_key[1].text=@"C#";
    lbl_key[2].text=@"D";
    lbl_key[3].text=@"D#";
    lbl_key[4].text=@"E";
    lbl_key[5].text=@"F";
    lbl_key[6].text=@"F#";
    lbl_key[7].text=@"G";
    lbl_key[8].text=@"G#";
    lbl_key[9].text=@"A";
    lbl_key[10].text=@"B";
    lbl_key[11].text=@"H";

    
    //--------------------------
    // METRONOME
    //--------------------------
    int area_offset = 720;
    lbl_tempo = [[UIShadowLabel alloc]initWithFrame:CGRectMake(area_offset+30,34,40,40)];
    lbl_tempo.text = @"100";
    lbl_tempo.font = [UIFont fontWithName:@"Futura-CondensedMedium" size:18];
    lbl_tempo.text_color = [UIColor colorWithRed:199/255.f green:166/255.f blue:144/255.f alpha:1.f];
    lbl_tempo.textColor = [UIColor colorWithRed:199/255.f green:166/255.f blue:144/255.f alpha:1.f];
    lbl_tempo.layer.shadowColor = [[UIColor colorWithRed:199/255.f green:166/255.f blue:144/255.f alpha:.9f] CGColor];
    lbl_tempo.textAlignment = UITextAlignmentCenter;
    lbl_tempo.layer.shadowRadius = 4.0f;
    lbl_tempo.layer.shadowOpacity = .9;
    lbl_tempo.layer.shadowOffset = CGSizeZero;
    lbl_tempo.layer.masksToBounds = YES;
    lbl_tempo.backgroundColor=[UIColor colorWithRed:0.f green:0.f blue:0.f alpha:0.f];
    [self.view addSubview:lbl_tempo];
    
    int val = [lbl_tempo.text integerValue];
    tempo = 60.0f/val;
    
    gesture_tempo_up = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(long_press_tempo:)];
    gesture_tempo_down = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(long_press_tempo:)];
    
    btn_tempo[TEMPO_UP] = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn_tempo[TEMPO_UP] addTarget:self action:@selector(tempo_up_cb:) forControlEvents:UIControlEventTouchDown];
    [btn_tempo[TEMPO_UP] addGestureRecognizer:gesture_tempo_up];
    
    btn_tempo[TEMPO_DOWN] = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn_tempo[TEMPO_DOWN] addTarget:self action:@selector(tempo_down_cb:) forControlEvents:UIControlEventTouchDown];
    [btn_tempo[TEMPO_DOWN] addGestureRecognizer:gesture_tempo_down];
    
    btn_tempo[TEMPO_START] = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn_tempo[TEMPO_START] addTarget:self action:@selector(tempo_start:) forControlEvents:UIControlEventTouchDown];
    
    btn_tempo[TEMPO_START].frame = CGRectMake(area_offset-58,  20, 54, 61);
    btn_tempo[TEMPO_UP].frame    = CGRectMake(area_offset+76,  33, 45, 25);
    btn_tempo[TEMPO_DOWN].frame  = CGRectMake(area_offset+120, 33, 45, 25);
    
    [btn_tempo[TEMPO_START] setBackgroundImage:[UIImage imageNamed:@"bt_metronom_off"] forState:UIControlStateNormal];
    [btn_tempo[TEMPO_UP] setBackgroundImage:[UIImage imageNamed:@"bt_plus_off"] forState:UIControlStateNormal];
    [btn_tempo[TEMPO_DOWN] setBackgroundImage:[UIImage imageNamed:@"bt_minus_off"] forState:UIControlStateNormal];
    
    [btn_tempo[TEMPO_START] setBackgroundImage:[UIImage imageNamed:@"bt_metronom_active"] forState:UIControlStateHighlighted];
    [btn_tempo[TEMPO_UP] setBackgroundImage:[UIImage imageNamed:@"bt_plus_off"] forState:UIControlStateNormal];
    [btn_tempo[TEMPO_DOWN] setBackgroundImage:[UIImage imageNamed:@"bt_minus_off"] forState:UIControlStateNormal];

    
    
    [self.view addSubview:btn_tempo[TEMPO_UP]];
    [self.view addSubview:btn_tempo[TEMPO_DOWN]];
    [self.view addSubview:btn_tempo[TEMPO_START]];
    
    
    //VOLUME SLIDE BAR
    //vertical
    CGAffineTransform trans1 = CGAffineTransformMakeRotation(M_PI * -90 / 180.0f);
    CGAffineTransform trans2=CGAffineTransformMakeScale(0.5f, 0.5f);
    CGAffineTransform trans_concat = CGAffineTransformConcat(trans1, trans2);
    
    
    for(int i=0; i<5; i++){
        
        slider_vol[i] = [[UISlider alloc]initWithFrame:CGRectMake(470+(i*71),170,440,80)];
        slider_vol[i].transform = trans_concat;
        slider_vol[i].minimumValue = 0.0;
        slider_vol[i].maximumValue = 1.0;
        slider_vol[i].value = 0.0;

        if(i<4){
            [slider_vol[i] setThumbImage:[UIImage imageNamed:@"slider_tempo"] forState:UIControlStateNormal ];
        }else{
            [slider_vol[i] setThumbImage:[UIImage imageNamed:@"slider_vol"] forState:UIControlStateNormal ];
        }
        [slider_vol[i] setMinimumTrackImage:[UIImage imageNamed:@"skeleton.png"] forState:UIControlStateNormal];
        [slider_vol[i] setMaximumTrackImage:[UIImage imageNamed:@"skeleton.png"] forState:UIControlStateNormal];
        
        [slider_vol[i] addTarget:self action:@selector(set_volume:)forControlEvents:UIControlEventValueChanged];
        [self.view addSubview:slider_vol[i]];
    }

    
    slider_vol[0].value = 0.5;
    slider_vol[4].value = 0.25;
    
    
    //MENU
    btn_menu[0] = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn_menu[0] addTarget:self action:@selector(show_info) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
    btn_menu[0].frame    = CGRectMake(screenH-70, 22, 51, 55);

    btn_menu[1] = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn_menu[1] addTarget:self action:@selector(show_help) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
    btn_menu[1].frame    = CGRectMake(screenH-120, 22, 51, 55);

    [btn_menu[0] setBackgroundImage:[UIImage imageNamed:@"bt_info"] forState:UIControlStateNormal];
    [btn_menu[1] setBackgroundImage:[UIImage imageNamed:@"bt_help"] forState:UIControlStateNormal];

    
    [self.view addSubview:btn_menu[0]];
    [self.view addSubview:btn_menu[1]];
    
    [self init_all];
}

-(NSString*) getKeyName:(int)idx{
    
    NSString* str;
    
    switch(idx){
        case 0: str = @"C";     break;
        case 1: str = @"C#";    break;
        case 2: str = @"D";     break;
        case 3: str = @"D#";    break;
        case 4: str = @"E";     break;
        case 5: str = @"F";     break;
        case 6: str = @"F#";    break;
        case 7: str = @"G";     break;
        case 8: str = @"G#";    break;
        case 9: str = @"A";     break;
        case 10: str = @"B";    break;
        case 11: str = @"H";    break;
        default:
            str = @"C";         break;
    }
    return str;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [[event allTouches] anyObject];
    int i = touch.view.tag;

    if( ([event touchesForView:lbl_pitch[i]] != NULL) ||
        ([event touchesForView:lbl_key[i]] != NULL)) {
    
        [self stopSoundAll];
        
        if( pitch_mode == EQUAL_TEMPERATE ){

            //キー移調
            NSString *item_name = [self getKeyName:i];
            selected_key = i;
            
            [self translate:selected_key:item_name];
            
        }else{
            //キー移調 Cに戻す
            NSString *item_name = [self getKeyName:0];
            selected_key = 0;
            [self translate:selected_key:item_name];
            
            
            //基準キーを設定
            [self change_mode: pitch_mode: i];
            [self set_key_bg:i];
        }
    }
}

-(void)set_key_bg:(int)i{
    
    [self clear_key_bg];
    
    // KEY ACTIVE背景
    key_bg[i].hidden = NO;

    lbl_key[i].text_color = [UIColor colorWithRed:0.f green:0.f blue:0.f alpha:1.f];
    lbl_pitch[i].text_color = [UIColor colorWithRed:0.f green:0.f blue:0.f alpha:1.f];
    
    [lbl_key[i] setNeedsDisplay];
    [lbl_pitch[i] setNeedsDisplay];
    
}

-(void)clear_key_bg{

    for(int i=0; i<12; i++){

        // KEY ACTIVE背景
        key_bg[i].hidden = YES;

        lbl_key[i].text_color = [UIColor colorWithRed:199/255.f green:166/255.f blue:144/255.f alpha:1.f];
        lbl_pitch[i].text_color = [UIColor colorWithRed:199/255.f green:166/255.f blue:144/255.f alpha:1.f];

        [lbl_key[i] setNeedsDisplay];
        [lbl_pitch[i] setNeedsDisplay];
    }

}



-(void)show_info{
 
    info_vc = [[InfoViewController alloc]initWithFrame:CGRectMake(0,0,1024,768)];
    [info_vc setInstance:self];

    info_vc.view.alpha = 0.0f;
    [self.view addSubview: info_vc.view];
    
    //fade in
    [UIView beginAnimations:@"fadeIn" context:nil];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
    [UIView setAnimationDuration:0.2f];
    info_vc.view.alpha = 1.f;
    [UIView commitAnimations];
    

}

-(void)close_info{

    //fade in
    [UIView beginAnimations:@"fadeOut" context:nil];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
    [UIView setAnimationDuration:0.2f];
    info_vc.view.alpha = 0.0f;
    [UIView commitAnimations];

    [info_vc.view removeFromSuperview];
}

-(void)show_help{

    help_vc = [[HelpViewController alloc]initWithFrame:CGRectMake(0,0,1024,768)];
    [help_vc setInstance:self];
    
    help_vc.view.alpha = 0.0f;
    [self.view addSubview: help_vc.view];
    
    //fade in
    [UIView beginAnimations:@"fadeIn" context:nil];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
    [UIView setAnimationDuration:0.2f];
    help_vc.view.alpha = 1.f;
    [UIView commitAnimations];
}

-(void)close_help{
    
    //fade in
    [UIView beginAnimations:@"fadeOut" context:nil];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
    [UIView setAnimationDuration:0.2f];
    help_vc.view.alpha = 0.0f;
    [UIView commitAnimations];
    
    [help_vc.view removeFromSuperview];
}


-(void)set_base_hz:(int)hz{
 
    if(device != NULL){
        
        for(int i=0; i<PITCH_NUM; i++){
            alSourceStop(key_sources[i]);
            alDeleteSources(1, &key_sources[i]);
            alDeleteBuffers(1, &key_buffers[i]);
        }
        alcMakeContextCurrent(NULL);
        alcDestroyContext(alContext);
        alcCloseDevice(device);
    }
    
    // OpneALデバイスを開く
    device = alcOpenDevice(NULL);
    
    // OpenALコンテキスを作成して、カレントにする
    alContext = alcCreateContext(device, NULL);
    alcMakeContextCurrent(alContext);
    
    // バッファとソースを作成する
    alGenBuffers(PITCH_NUM, key_buffers);
    alGenSources(PITCH_NUM, key_sources);
    
    /*sin波を作成*/
    int DATA_NUM=88200;         //プチノイズ対策　※高音がだめ
    ALshort data[DATA_NUM];
    for (int i = 0; i < DATA_NUM ; i++)
    {
          data[i] = 32767 * sin(i * M_PI * 2 * hz / DATA_NUM);
//Cl
//        data[i] = 32767 * ((sin(i * M_PI * 2 * hz / DATA_NUM) +
//                            sin(i * M_PI * 2 * hz*3 / DATA_NUM)
//                            ))/2;

    }
    for (int i=0; i < PITCH_NUM; i++) {

        alBufferData(key_buffers[i], AL_FORMAT_STEREO16, data, sizeof(data), DATA_NUM);
        alSourcei( key_sources[i], AL_BUFFER, key_buffers[i]);
        alSourcei( key_sources[i], AL_LOOPING, AL_TRUE );
    }
}

-(void) setEqualTemperament
{
    float debug_val[PITCH_NUM];
    float val = 1.f;
    
    for (int i =  base_key; i >=0; i--) {

        alSourcef(key_sources[i], AL_PITCH, val);
        key_pitch[i] = val;
        debug_val[i] = val;
        val/=POW_2;
    }

    val = 1.f;

    for (int i = (base_key+1); i < PITCH_NUM; i++) {

        val*=POW_2;
        alSourcef(key_sources[i], AL_PITCH, val);
        key_pitch[i] = val;
    }
    
//    for(int i=0; i<PITCH_NUM;i++){
//        printf("%f\n",key_pitch[i]);
//    }
}

-(void) setPurePitch
{
    float debug_val[PITCH_NUM];
    float val = 1.f;

    int base_key_num = 9;
    int j = base_key_num;

    for (int i =  base_key; i >=0; i--) {
        
        float f_tmp = [lbl_pitch[j].text floatValue];
        if(f_tmp == 0){
            f_tmp=1.0f;
        }
        [lbl_pitch[j] setNeedsDisplay];
        
        alSourcef(key_sources[i], AL_PITCH, val);
        key_pitch[i] = val;
        val/=POW_2;
    }
    
    val = 1.f;
    
    for (int i = (base_key+1); i < PITCH_NUM; i++) {
        
        val*=POW_2;
        alSourcef(key_sources[i], AL_PITCH, val);
        key_pitch[i] = val;
    }

    for(int i=0; i<12; i++){
        [self set_pitch:i:0.f];
    }

//    for(int i=0; i<PITCH_NUM;i++){
//        printf("%f\n",key_pitch[i]);
//    }
}




-(void)highlightReset:(id)sender{
    UIButton *button = (UIButton *)sender;
    button.highlighted = NO;
}

- (void)highlighted:(id)sender{
    NSLog(@"highlightedFlag");
    UIButton *button = (UIButton *)sender;
    button.highlighted = YES;
}




-(void) change_mode:(int)mode:(int)base_key{

    int j = base_key;
    
    switch(mode){
           
        //平均律
        case EQUAL_TEMPERATE:
 
            [self clear_key_bg];
            for(int i=0; i<12; i++){
                lbl_key[i].enabled = true;
                lbl_pitch[i].text = [NSString stringWithFormat:@"%02.01f",0.0f];
                [lbl_pitch[i] setNeedsDisplay];
            }
            
            [btn_pitch[0] setBackgroundImage:[UIImage imageNamed:@"bt_on"] forState:UIControlStateNormal];
            [btn_pitch[1] setBackgroundImage:[UIImage imageNamed:@"bt_off"] forState:UIControlStateNormal];
            [btn_pitch[2] setBackgroundImage:[UIImage imageNamed:@"bt_off"] forState:UIControlStateNormal];
            
            [self setEqualTemperament];

            break;
            
        //純正律 MAJOR
        case JYUNSEI_MAJOR:

            [btn_pitch[0] setBackgroundImage:[UIImage imageNamed:@"bt_off"] forState:UIControlStateNormal];
            [btn_pitch[1] setBackgroundImage:[UIImage imageNamed:@"bt_on"] forState:UIControlStateNormal];
            [btn_pitch[2] setBackgroundImage:[UIImage imageNamed:@"bt_off"] forState:UIControlStateNormal];
            
            for(int i=0; i<12; i++){
                lbl_key[i].enabled = true;
                lbl_pitch[j].text = [NSString stringWithFormat:@"%02.01f",major_pitch[i]];
                [lbl_pitch[i] setNeedsDisplay];
                j++;
                if(j>=12){
                    j=0;
                }
            }
            [self setPurePitch];
            break;

        //純正律 MINOR
        case JYUNSEI_MINOR:
            
            [btn_pitch[0] setBackgroundImage:[UIImage imageNamed:@"bt_off"] forState:UIControlStateNormal];
            [btn_pitch[1] setBackgroundImage:[UIImage imageNamed:@"bt_off"] forState:UIControlStateNormal];
            [btn_pitch[2] setBackgroundImage:[UIImage imageNamed:@"bt_on"] forState:UIControlStateNormal];


            for(int i=0; i<12; i++){
                lbl_key[i].enabled = true;
                 lbl_pitch[j].text = [NSString stringWithFormat:@"%02.01f",minor_pitch[i]];
                [lbl_pitch[i] setNeedsDisplay];

                j++;
                if(j>=12){
                    j=0;
                }
            }
            [self setPurePitch];
            break;
            
        default:
            break;
    }
}

- (void)buttonPush:(UIButton *)sender{

    // play click sound
    alSourcePlay(click_source);
    
    pitch_mode = sender.tag;

    [self translate:0: @"C"];
}


- (void)hz_up:(UIButton*)sender
{
    
    pitch_val += 1;
    lbl_hz.text = [NSString stringWithFormat:@"%003d Hz", pitch_val ];
    [lbl_hz setNeedsDisplay];
    

    [self init_all];

    // play click sound
    alSourcePlay(click_source);
}

- (void)hz_down:(UIButton*)sender
{

    pitch_val -= 1;

    lbl_hz.text = [NSString stringWithFormat:@"%003d Hz",pitch_val ];
    [lbl_hz setNeedsDisplay];

    [self init_all];
    // play click sound
    alSourcePlay(click_source);

}



//-----------------------------
// 転調キー選択
//-----------------------------
//-(void) basekey_selected {
//
//    // PickerViewControllerを生成
//    PickerViewController *pickerViewController;
//    pickerViewController = [[PickerViewController alloc]
//                            initWithNibName:@"PickerViewController"
//                            bundle:nil];
//    pickerViewController.contentSizeForViewInPopover = CGSizeMake(200, 266);    // 表示サイズ指定（重要）
//    pickerViewController.mInstance = self;
//    
//    if (self.popOver == nil)
//    {
//        self.popOver = [[UIPopoverController alloc] initWithContentViewController:pickerViewController];
//        self.popOver.delegate = self;
//        
////        self.popOver.popoverBackgroundViewClass = [PrgPopoverBackgroundView class];
//    }
//    
//    // ポップオーバーが現在表示されていなければ表示する
//    if (!self.popOver.popoverVisible)
//    {
//        [self.popOver presentPopoverFromRect:CGRectMake(540, 0, 100, 70)
//                                      inView:self.view
//                    permittedArrowDirections:UIPopoverArrowDirectionUp   // 矢印の向きを指定する
//                                    animated:YES];
//    }
//    
//}



int pitch_idx = 0;
int selected_key = 0;

- (void)key_selected:(UILabel*)sender
{
    selected_key = sender.tag;
    [self change_mode: pitch_mode: selected_key];
    
}


- (void)pitch_up:(UIButton*)sender
{
    // play click sound
    alSourcePlay(click_source);
    
    [self stop_pitch_timer];
    
    pitch_idx = sender.tag;

    [self set_pitch:pitch_idx:0.1f];
}

-(void)set_pitch:(int)idx:(float)val{

   
    float f_tmp = [ lbl_pitch[idx].text floatValue];
    f_tmp += val;

    float pitch = pow(POW_1CENT,f_tmp);

    lbl_pitch[idx].text = [NSString stringWithFormat:@"%02.01f",f_tmp];
    [lbl_pitch[idx] setNeedsDisplay];
    
    for(int i=0; i<PITCH_NUM; i+=12){
        alSourcef (key_sources[idx+i], AL_PITCH, key_pitch[idx+i]*pitch);
    }
}

- (void)pitch_down:(UIButton*)sender
{
    // play click sound
    alSourcePlay(click_source);

    [self stop_pitch_timer];

    pitch_idx = sender.tag;
    
    [self set_pitch:pitch_idx:-0.1f];
}

NSTimer* timer_tempo_longpress;

-(void)LongPressedPitch:(UILongPressGestureRecognizer *)sender{
    
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
            
            if( sender == long_press_up[0] ||
                sender == long_press_up[1] ||
               sender == long_press_up[2] ||
               sender == long_press_up[3] ||
               sender == long_press_up[4] ||
               sender == long_press_up[5] ||
               sender == long_press_up[6] ||
               sender == long_press_up[7] ||
               sender == long_press_up[8] ||
               sender == long_press_up[9] ||
               sender == long_press_up[10] ||
               sender == long_press_up[11] ){
                
                    timer_tempo_longpress =
                    [NSTimer
                     scheduledTimerWithTimeInterval:0.02f
                     target:self
                     selector:@selector(sel_pitch_up_timer)
                     userInfo:nil
                     repeats:YES];
            
            }else if( sender == long_press_down[0] ||
                     sender == long_press_down[1] ||
                     sender == long_press_down[2] ||
                     sender == long_press_down[3] ||
                     sender == long_press_down[4] ||
                     sender == long_press_down[5] ||
                     sender == long_press_down[6] ||
                     sender == long_press_down[7] ||
                     sender == long_press_down[8] ||
                     sender == long_press_down[9] ||
                     sender == long_press_down[10] ||
                     sender == long_press_down[11] ){
            
                    timer_tempo_longpress =
                    [NSTimer
                     scheduledTimerWithTimeInterval:0.02f
                     target:self
                     selector:@selector(sel_pitch_down_timer)
                     userInfo:nil
                     repeats:YES];
            }else{
                //nothing
            }
            break;
            
        case UIGestureRecognizerStateEnded:
            
            [self stop_pitch_timer];
            break;
    }
}

-(void)stop_pitch_timer{

    if (timer_tempo_longpress) {
        if ([timer_tempo_longpress isValid]) {
            [timer_tempo_longpress invalidate];
            timer_tempo_longpress = nil;
        }
    }

}


-(void)sel_pitch_up_timer{
    
    [self set_pitch:pitch_idx:0.1f];
}

-(void)sel_pitch_down_timer{

    [self set_pitch:pitch_idx:-0.1f];
    
}



-(void)set_volume:(UISlider*)slider
{
    
    if(slider == slider_vol[SLIDER_VOL_4]){

        alSourcef (_sources[SLIDER_VOL_4], AL_GAIN, slider.value);
        
    }else if(slider == slider_vol[SLIDER_VOL_8]){

        alSourcef (_sources[SLIDER_VOL_8], AL_GAIN, slider.value);

    }else if(slider == slider_vol[SLIDER_VOL_16]){

        alSourcef (_sources[SLIDER_VOL_16], AL_GAIN, slider.value);
        
    }else if(slider == slider_vol[SLIDER_VOL_3]){

        alSourcef (_sources[SLIDER_VOL_3], AL_GAIN, slider.value);
        
    }else if(slider == slider_vol[SLIDER_VOL_ALL]){
        
        for (int i = 0; i < PITCH_NUM; i++) {
            alSourcef (key_sources[i], AL_GAIN, slider.value);
        }
    }
}

- (void)playSound:(UIButton*)sender
{
    NSInteger index = sender.tag;
    int offset = 0;
    if(translate_key > 6){
        offset = translate_key - 12;
    }else{
        offset = translate_key;
    }
    ALint state;
    alGetSourcei(key_sources[index +12+ offset], AL_SOURCE_STATE, &state);
//    if(state != AL_PLAYING){
//        alSourceRewind(key_sources[index +12+ offset]);
//    }
    alSourcePlay(key_sources[index +12+ offset]);

}

- (void)stopSound:(UIButton*)sender
{
    NSInteger index = sender.tag;
    int offset = 0;
    if(translate_key > 6){
        offset = translate_key - 12;
    }else{
        offset = translate_key;
    }

    alSourceStop(key_sources[index+12+offset]);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

int translate_key = 0;
//-------------------------------
// キー移調
//-------------------------------
-(void)translate:(int)key: (NSString*)item_name{
    
    translate_key = key;
    selected_key = key;
    
    [self change_mode: pitch_mode: key];
    [self set_key_bg:key];
    
    NSLog(@"translate key=%d",key);
}


-(void)initClickSound{
    
    // バッファとソースを作成する
    alGenBuffers(1, &click_buffer);
    alGenSources(1, &click_source);
    
    NSString* path = [[NSBundle mainBundle] pathForResource:@"click" ofType:@"mp3"];
    
    // オーディオデータを取得する
    void*   audioData;
    ALsizei dataSize;
    ALenum  dataFormat;
    ALsizei sampleRate;
    audioData = GetOpenALAudioData((__bridge CFURLRef)[NSURL fileURLWithPath:path], &dataSize, &dataFormat, &sampleRate);
    
    // データをバッファに設定する
    alBufferData(click_buffer, dataFormat, audioData, dataSize, sampleRate);
    
    // バッファをソースに設定する
    alSourcei(click_source, AL_BUFFER, click_buffer);

    alSourcef (click_source, AL_GAIN, .1f);


}


//-------------------------------
// METRONOME
//-------------------------------
-(void)init_sounds{
    
    // バッファとソースを作成する
    alGenBuffers(4, _buffers);
    alGenSources(4, _sources);

    for (int i = 0; i < 4; i++) {
        // サウンドファイルパスを取得する
        NSString*   fileName = nil;
        NSString*   path;
        switch (i) {
            case 0: fileName = @"count"; break;
            case 1: fileName = @"count"; break;
            case 2: fileName = @"count"; break;
            case 3: fileName = @"count"; break;
            default:
                fileName = @"count"; break;
        }
        path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"m4a"];
    
        // オーディオデータを取得する
        void*   audioData;
        ALsizei dataSize;
        ALenum  dataFormat;
        ALsizei sampleRate;
        audioData = GetOpenALAudioData((__bridge CFURLRef)[NSURL fileURLWithPath:path], &dataSize, &dataFormat, &sampleRate);
        
        // データをバッファに設定する
        alBufferData(_buffers[i], dataFormat, audioData, dataSize, sampleRate);
        
        // バッファをソースに設定する
        alSourcei(_sources[i], AL_BUFFER, _buffers[i]);
        
        // ボリューム設定
        [self set_volume:slider_vol[i]];
    }

}

- (void)tempo_up:(UIButton*)sender
{
    int val = [lbl_tempo.text integerValue];
    val += 1;
    
    if(val >= 220){
        val = 220;
    }
    lbl_tempo.text = [NSString stringWithFormat : @"%d", val];
    tempo = 60.0f/val;
}

- (void)tempo_down:(UIButton*)sender
{
    int val = [lbl_tempo.text integerValue];
    val -= 1;
    if( val <= 0 ){
        val = 0;
    }
    lbl_tempo.text = [NSString stringWithFormat : @"%d", val];
    tempo = 60.0f/val;
}

- (void)tempo_up_cb:(UIButton*)sender
{
    // play click sound
    alSourcePlay(click_source);
    
    [self tempo_up:sender];
}

- (void)tempo_down_cb:(UIButton*)sender
{
    // play click sound
    alSourcePlay(click_source);
    
    [self tempo_down:sender];
}

- (void)tempo_up_cb_longpress:(UIButton*)sender
{
    [self tempo_up:sender];
}

- (void)tempo_down_cb_longpress:(UIButton*)sender{
    
    [self tempo_down:sender];
}




-(void)long_press_tempo:(UILongPressGestureRecognizer *)sender{
    
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
            if(sender == gesture_tempo_up){

                timer_tempo_longpress =
                    [NSTimer
                     scheduledTimerWithTimeInterval:0.05f    // タイマーの間隔を秒単位で指定
                     target:self                     // 第三引数で指定したメッセージの送付先オブジェクト名
                     selector:@selector(sel_tempo_up_timer)  // 第一引数で指定した時間が経過した時に送付されるメッセージ名
                     userInfo:nil            // タイマー起動中に参照するオブジェクト
                     repeats:YES];                    // タイマーを継続して動作させるかどうかの指定
            }else if(sender == gesture_tempo_down){
                timer_tempo_longpress =
                    [NSTimer
                     scheduledTimerWithTimeInterval:0.05f    // タイマーの間隔を秒単位で指定
                     target:self                     // 第三引数で指定したメッセージの送付先オブジェクト名
                     selector:@selector(sel_tempo_down_timer)  // 第一引数で指定した時間が経過した時に送付されるメッセージ名
                     userInfo:nil            // タイマー起動中に参照するオブジェクト
                     repeats:YES];                    // タイマーを継続して動作させるかどうかの指定
            }
        break;

    case UIGestureRecognizerStateEnded:

        if (timer_tempo_longpress) {
            if ([timer_tempo_longpress isValid]) {
                [timer_tempo_longpress invalidate];
                timer_tempo_longpress = nil;
            }
        }
        break;
    }
}

-(void)sel_tempo_up_timer{
    [self tempo_up_cb_longpress:nil];
}

-(void)sel_tempo_down_timer{
    [self tempo_down_cb_longpress:nil];
}

-(void)tempo_start:(UIButton*)sender
{
    // play click sound
    alSourcePlay(click_source);
    
    if(is_running == NO){
        
        [btn_tempo[TEMPO_START] setBackgroundImage:[UIImage imageNamed:@"bt_metronom_on"] forState:UIControlStateNormal];
        
        timer_tempo =
            [NSTimer
             scheduledTimerWithTimeInterval:tempo    // タイマーの間隔を秒単位で指定
             target:self                     // 第三引数で指定したメッセージの送付先オブジェクト名
             selector:@selector(event_repeat)  // 第一引数で指定した時間が経過した時に送付されるメッセージ名
             userInfo:nil            // タイマー起動中に参照するオブジェクト
             repeats:NO];                    // タイマーを継続して動作させるかどうかの指定
        is_running = YES;

    }else{

        [btn_tempo[TEMPO_START] setBackgroundImage:[UIImage imageNamed:@"bt_metronom_off"] forState:UIControlStateNormal];

        is_running = NO;
        if (timer_tempo) {
            if ([timer_tempo isValid]) {
                [timer_tempo invalidate];
                timer_tempo = nil;
            }
        }
    }
}


- (void)event_repeat_3
{
    if(is_running==YES){

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
            alSourcePlay(_sources[SLIDER_VOL_3]);
        });
        
        count_3ren++;
        if( count_3ren < 2 ){

            timer_tempo_3 =
            [NSTimer
             scheduledTimerWithTimeInterval:tempo/3    // タイマーの間隔を秒単位で指定
             target:self                     // 第三引数で指定したメッセージの送付先オブジェクト名
             selector:@selector(event_repeat_3)  // 第一引数で指定した時間が経過した時に送付されるメッセージ名
             userInfo:nil            // タイマー起動中に参照するオブジェクト
             repeats:NO];                    // タイマーを継続して動作させるかどうかの指定
        }
    }
}

- (void)event_repeat
{
    if(is_running==YES){
        
        if(count_16 == 0){
        
            count_3ren = 0;
            timer_tempo_3 =
                [NSTimer
                 scheduledTimerWithTimeInterval:tempo/3    // タイマーの間隔を秒単位で指定
                 target:self                     // 第三引数で指定したメッセージの送付先オブジェクト名
                 selector:@selector(event_repeat_3)  // 第一引数で指定した時間が経過した時に送付されるメッセージ名
                 userInfo:nil            // タイマー起動中に参照するオブジェクト
                 repeats:NO];                    // タイマーを継続して動作させるかどうかの指定
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
        
            if(count_16 == 0){
                alSourcePlay(_sources[SLIDER_VOL_4]);
                alSourcePlay(_sources[SLIDER_VOL_8]);
                alSourcePlay(_sources[SLIDER_VOL_3]);
            }
            if( count_16 == 2 ){
                alSourcePlay(_sources[SLIDER_VOL_8]);
            }
            
            alSourcePlay(_sources[SLIDER_VOL_16]);
            
            //reset counter
            count_16++;
            if(count_16 >= 4){
                count_16 = 0;
            }
        });
        
        timer_tempo =
            [NSTimer
             scheduledTimerWithTimeInterval:tempo/4    // タイマーの間隔を秒単位で指定
             target:self                     // 第三引数で指定したメッセージの送付先オブジェクト名
             selector:@selector(event_repeat)  // 第一引数で指定した時間が経過した時に送付されるメッセージ名
             userInfo:nil            // タイマー起動中に参照するオブジェクト
             repeats:NO];                    // タイマーを継続して動作させるかどうかの指定
    }
    
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView{

    [self stopSoundAll];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    
    [self stopSoundAll];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {

    [self stopSoundAll];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {

    [self stopSoundAll];
}



@end
