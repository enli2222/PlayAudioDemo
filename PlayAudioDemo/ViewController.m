//
//  ViewController.m
//  PlayAudioDemo
//
//  Created by enli on 2018/5/31.
//  Copyright © 2018年 enli. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
{
    UIButton *btnPlayStart,*btnPlayEnd,*btnPlayPause;
    UIButton *btnRecordStart,*btnRecordEnd;
    UIButton *btnRefresh;
    UILabel *lbtitle1,*lbtitle2,*lbvalue1,*lbvalue2;
    AVAudioPlayer *_player;
    AVAudioRecorder *_recorder;
    NSString *kRecordAudioFile;
    NSTimer *_playTimer,*_recordTimer;
    UIProgressView *audioPower;
    UITableView *tbFileList;
}
@end

@implementation ViewController

-(UIButton *)setButton:(NSString *)title top:(NSInteger)y left:(NSInteger)x action:(SEL)action{
    UIButton * btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.backgroundColor = [UIColor redColor];
    btn.frame = CGRectMake(x, y, 100, 30);
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:15.0];
    [self.view addSubview:btn];
    return btn;
}

-(UILabel *)setLabel:(NSString *)title top:(NSInteger)y left:(NSInteger)x{
    UILabel *lb = [UILabel new];
    lb.frame = CGRectMake(x, y, 150, 30);
    lb.text = title;
    [self.view addSubview:lb];
    return lb;
}

-(void)setProgressView{
    if(!audioPower){
        audioPower = [[UIProgressView alloc] initWithFrame:CGRectMake(20, 150, 320, 40)];
        audioPower.progressTintColor = [UIColor blueColor];
        audioPower.progress = 0.0;
        /*
         typedef NS_ENUM(NSInteger, UIProgressViewStyle) {
         UIProgressViewStyleDefault,     // normal progress bar
         UIProgressViewStyleBar __TVOS_PROHIBITED,     // for use in a toolbar
         };
         */
        audioPower.progressViewStyle = UIProgressViewStyleDefault;
        [self.view addSubview:audioPower];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    kRecordAudioFile = @"myRecord.wav";
    
    btnPlayStart = [self setButton:@"播放音频" top:50 left:20 action:@selector(onPlayStart:)];

    btnPlayEnd = [self setButton:@"停止播放" top:50 left:140 action:@selector(onPlayEnd:)];
    
    btnPlayPause = [self setButton:@"暂停播放" top:50 left:260 action:@selector(onPlayPause:)];
    
    btnRecordStart = [self setButton:@"开始录音" top:100 left:20 action:@selector(onRecordStart:)];
    
    btnRecordEnd = [self setButton:@"停止录音" top:100 left:140 action:@selector(onRecordEnd:)];
    
    btnRecordEnd = [self setButton:@"暂停录音" top:100 left:260 action:@selector(onRecordPause:)];
    
    btnRefresh = [self setButton:@"刷新文件" top:220 left:20 action:@selector(onRefreshFile:)];
    
    lbtitle1 = [self setLabel:@"音频强度:" top:150 left:20];
    lbvalue1 = [self setLabel:@"0.0" top:150 left:120];
    lbtitle2 = [self setLabel:@"音频时间:" top:180 left:20];
    lbvalue2 = [self setLabel:@"0s" top:180 left:120];
    
//    [self setProgressView];
    [self setAudioSession];
    
}

//设置拔耳机静音
-(void)setRouteChange{
    NSNotificationCenter *nsnc = [NSNotificationCenter defaultCenter];
    [nsnc addObserver:self selector:@selector(handleRouteChange:) name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];
}

-(void)setAudioSession{
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
    //建议在播放之前设置yes，播放结束设置NO。这个功能是开启红外感应
    //加入监听
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sensorStateChange:) name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
    
//    //初始化播放器的时候例如以下设置
//    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
//AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,sizeof(sessionCategory),&sessionCategory);
//    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
//    AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute, sizeof (audioRouteOverride),&audioRouteOverride);
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:YES error:nil];
//    配置音频会话后，如果锁屏的话，播放依旧会停止，如果要继续播放音乐需要target->capabilities 钩上 Backgrounds Modes里面的第一个选项
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    
}

//处理监听触发事件
-(void)sensorStateChange:(NSNotificationCenter *)notification;
{
    //假设此时手机靠近面部放在耳朵旁，那么声音将通过听筒输出。并将屏幕变暗（省电啊）
    if ([[UIDevice currentDevice] proximityState] == YES)
    {
        NSLog(@"人靠近设备");
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    }
    else
    {
        NSLog(@"人远离设备");
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    }
}

- (void)handleRouteChange:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    AVAudioSessionRouteChangeReason reason = [info[AVAudioSessionRouteChangeReasonKey] unsignedIntValue];
//    拔出耳机的时候通知AVAudioSessionRouteChangeReasonOldDeviceUnavailable，指旧设备不可用，例如耳机拔出。插入耳机的时候通知AVAudioSessionRouteChangeReasonNewDeviceAvailable，指新设备可用，例如耳机插入。可以通过这个来控制音频的播放与暂停。
    if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        AVAudioSessionRouteDescription *previousRoute = info[AVAudioSessionRouteChangePreviousRouteKey];
        AVAudioSessionPortDescription *previousOutput = previousRoute.outputs[0];
        NSString *portType = previousOutput.portType;
        if ([portType isEqualToString:AVAudioSessionPortHeadphones]) {
            if ([self getPlayer].isPlaying) {
                [[self getPlayer] stop];//当拔出耳机的时候，停止播放
            }
        }
    }
}

/**
 *  获得录音机对象
 *
 *  @return 录音机对象
 */
-(AVAudioRecorder *)getRecorder{
    if(!_recorder){
        //创建录音文件保存路径
        NSURL *url = [self getSavePath];
        //创建录音格式设置
        NSDictionary *setting = [self getAudioSetting];
        //创建录音机
        NSError *error =nil;
        _recorder = [[AVAudioRecorder alloc]initWithURL:url settings:setting error:&error];
        _recorder.delegate =self;
        _recorder.meteringEnabled=YES;//如果要监控声波则必须设置为YES
        if (error) {
            NSLog(@"创建录音机对象时发生错误，错误信息：%@",error.localizedDescription);
            return nil;
        }
    }
    return _recorder;
}

/**
 *  创建播放器
 *
 *  @return 播放器
 */
-(AVAudioPlayer *)getPlayer{
    if (!_player) {
        NSURL *url = [self getSavePath];
//        NSURL *url = [self getPlayPath];
        NSError *error=nil;
        _player=[[AVAudioPlayer alloc]initWithContentsOfURL:url error:&error];
        _player.numberOfLoops=0;
        _player.delegate = self;
        [_player prepareToPlay];
        if (error) {
            NSLog(@"创建播放器过程中发生错误，错误信息：%@",error.localizedDescription);
            return nil;
        }
    }
    return _player;
}

-(void)goThroughAllatPath:(NSString *)path{
    NSLog(@"目录:%@",path);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *fileList = [[NSArray alloc] init];
    fileList = [fileManager contentsOfDirectoryAtPath:path error:&error];
    BOOL isDir = NO;
    //在上面那段程序中获得的fileList中列出文件夹名
    for (NSString *file in fileList) {
        NSString *subpath = [path stringByAppendingPathComponent:file];
        [fileManager fileExistsAtPath:subpath isDirectory:(&isDir)];
        if (isDir) {
//            NSLog(@"目录:%@ ",file);
            [self goThroughAllatPath:subpath];
        }else{
            NSLog(@"文件:%@ ",subpath);
        }
        isDir = NO;
    }
}

-(IBAction)onRefreshFile:(id)sender{
    NSLog(@"NSAllLibrariesDirectory");
    [self goThroughAllatPath:[NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory, NSUserDomainMask, YES) lastObject]];
    NSLog(@"NSDocumentDirectory");
    [self goThroughAllatPath:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]];
    NSLog(@"NSUserDirectory");
    [self goThroughAllatPath:[NSSearchPathForDirectoriesInDomains(NSUserDirectory, NSUserDomainMask, YES) lastObject]];
    NSLog(@"NSLibraryDirectory");
    [self goThroughAllatPath:[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]];
    NSLog(@"NSApplicationDirectory");
    [self goThroughAllatPath:[NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSUserDomainMask, YES) lastObject]];
    NSLog(@"resourcePath");
    [self goThroughAllatPath:[[NSBundle mainBundle] resourcePath]];
    NSLog(@"bundlePath");
    [self goThroughAllatPath:[[NSBundle mainBundle] bundlePath]];
    NSLog(@"executablePath");
    [self goThroughAllatPath:[[NSBundle mainBundle] executablePath]];
    NSLog(@"privateFrameworksPath");
    [self goThroughAllatPath:[[NSBundle mainBundle] privateFrameworksPath]];
    NSLog(@"sharedFrameworksPath");
    [self goThroughAllatPath:[[NSBundle mainBundle] sharedFrameworksPath]];
    NSLog(@"sharedSupportPath");
    [self goThroughAllatPath:[[NSBundle mainBundle] sharedSupportPath]];
    NSLog(@"builtInPlugInsPath");
    [self goThroughAllatPath:[[NSBundle mainBundle] builtInPlugInsPath]];
    
}

-(NSURL *)getSavePath{
    NSString *urlStr = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    urlStr = [urlStr stringByAppendingPathComponent:kRecordAudioFile];
    NSLog(@"file path:%@",urlStr);
    NSURL *url = [NSURL fileURLWithPath:urlStr];
    return url;
}

-(NSURL *)getPlayPath{
    return [[NSBundle mainBundle] URLForResource:@"testTTSfunctioncase111_16K16bit" withExtension:@"wav"];
}

-(NSDictionary *)getAudioSetting{
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    //设置录音格式
    [dic setObject:@(kAudioFormatLinearPCM)forKey:AVFormatIDKey];
    
    //设置录音采样率，8000是电话采样率，对于一般录音已经够了
    [dic setObject:@(16000)forKey:AVSampleRateKey];
    
    //设置通道,这里采用单声道
    [dic setObject:@(1)forKey:AVNumberOfChannelsKey];
    
    //每个采样点位数,分为8、16、24、32
    [dic setObject:@(16)forKey:AVLinearPCMBitDepthKey];
    
    //是否使用浮点数采样
    [dic setObject:@(YES)forKey:AVLinearPCMIsFloatKey];
    
    //....其他设置等
    
    return dic;
}

/**
 *  录音声波监控定制器
 *
 *  @return 定时器
 */
-(NSTimer *)getPlayTimer{
    if (!_playTimer) {
        _playTimer=[NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(audioPlayChange) userInfo:nil repeats:YES];
    }
    return _playTimer;
}
-(NSTimer *)getRecordTimer{
    if (!_recordTimer) {
        _recordTimer=[NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(audioPowerChange) userInfo:nil repeats:YES];
    }
    return _recordTimer;
}

-(void)audioPlayChange{
//    if ([self getPlayer].playing) {
        float duTime = [self getPlayer].duration;
        float cuTime = [self getPlayer].currentTime;
        lbvalue2.text = [NSString stringWithFormat:@"%.2f/%.2fs",cuTime,duTime];
//        [[self getPlayer] updateMeters];//更新测量值
//        float power = [self.getPlayer averagePowerForChannel:0];
//        lbvalue1.text = [NSString stringWithFormat:@"%.2f",power];
//    }
}

/**
 *  录音声波状态设置
 */
-(void)audioPowerChange{
    AVAudioRecorder *recoder = [self getRecorder];
    [recoder updateMeters];//更新测量值
    float cuTime = recoder.currentTime;
    //取得第一个通道的音频，注意音频强度范围时-160到0
    float power= [recoder averagePowerForChannel:0];
//    if ([NSThread isMainThread]) {
//        NSLog(@"主进程");
//    }else{
//        NSLog(@"线程");
//    }
//    dispatch_async(dispatch_get_main_queue(), ^{
//        //回调或者说是通知主线程刷新，
//    [lbvalue1 setNeedsDisplay];
//    });
    lbvalue1.text = [NSString stringWithFormat:@"%.2f",power];
    if(cuTime>0){
        lbvalue2.text = [NSString stringWithFormat:@"%.2fs",cuTime];
    }
//    CGFloat progress=(1.0/160.0)*(power+160.0);
//    [audioPower setProgress:progress];
}

-(IBAction)onRecordStart:(id)sender{
    if (![[self getRecorder] isRecording]) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        [[self getRecorder] record];
        [self getRecordTimer].fireDate = [NSDate distantPast];
        NSLog(@"%@",((UIButton *)sender).currentTitle);
    }
    
}
-(IBAction)onRecordEnd:(id)sender{
        [[self getRecorder] stop];
        [self getRecordTimer].fireDate = [NSDate distantFuture];
        audioPower.progress = 0.0;
        NSLog(@"%@",((UIButton *)sender).currentTitle);
 
}
-(IBAction)onRecordPause:(id)sender{
    if ([[self getRecorder] isRecording]) {
        [[self getRecorder] pause];
        [self getRecordTimer].fireDate = [NSDate distantFuture];
        NSLog(@"%@",((UIButton *)sender).currentTitle);
    }
}
-(IBAction)onPlayStart:(id)sender{
    if (![[self getPlayer] isPlaying]) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[self getPlayer] play];
        [self getPlayTimer].fireDate = [NSDate distantPast];
        NSLog(@"%@",((UIButton *)sender).currentTitle);
    }
}
-(IBAction)onPlayEnd:(id)sender{
    [[self getPlayer] stop];
    [self getPlayTimer].fireDate = [NSDate distantFuture];
    NSLog(@"%@",((UIButton *)sender).currentTitle);
}

-(IBAction)onPlayPause:(id)sender{
    [[self getPlayer] pause];
    [self getPlayTimer].fireDate = [NSDate distantFuture];
    NSLog(@"%@",((UIButton *)sender).currentTitle);
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
    NSLog(@"播发完成!");
    [self getPlayTimer].fireDate = [NSDate distantFuture];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError * __nullable)error{
    NSLog(@"播放发生错误，错误信息：%@",error.localizedDescription);
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag{
    NSLog(@"录音完成!");
}
- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError * __nullable)error{
    NSLog(@"录制发生错误，错误信息：%@",error.localizedDescription);
}
    
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
