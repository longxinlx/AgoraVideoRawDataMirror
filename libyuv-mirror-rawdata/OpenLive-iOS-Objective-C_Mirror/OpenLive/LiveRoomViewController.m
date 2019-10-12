//
//  LiveRoomViewController.m
//  OpenLive
//
//  Created by GongYuhua on 2016/9/12.
//  Copyright © 2016年 Agora. All rights reserved.
//

#import "LiveRoomViewController.h"
#import "VideoSession.h"
#import "VideoViewLayouter.h"
#import "BeautyEffectTableViewController.h"
#import "KeyCenter.h"
#import "AGVideoPreProcessing.h"

@interface LiveRoomViewController () <AgoraRtcEngineDelegate, BeautyEffectTableVCDelegate, UIPopoverPresentationControllerDelegate>
@property (weak, nonatomic) IBOutlet UILabel *roomNameLabel;
@property (weak, nonatomic) IBOutlet UIView *remoteContainerView;
@property (weak, nonatomic) IBOutlet UIButton *broadcastButton;
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *sessionButtons;
@property (weak, nonatomic) IBOutlet UIButton *audioMuteButton;
@property (weak, nonatomic) IBOutlet UIButton *beautyEffectButton;
@property (weak, nonatomic) IBOutlet UIButton *superResolutionButton;

@property (assign, nonatomic) BOOL isBroadcaster;
@property (assign, nonatomic) BOOL isMuted;
@property (assign, nonatomic) BOOL isMirror;
@property (assign, nonatomic) BOOL shouldEnhancer;
@property (strong, nonatomic) NSMutableArray<VideoSession *> *videoSessions;
@property (strong, nonatomic) VideoSession *fullSession;
@property (strong, nonatomic) VideoViewLayouter *viewLayouter;
@property (assign, nonatomic) BOOL isEnableSuperResolution;
@property (assign, nonatomic) NSUInteger highPriorityRemoteUid;
@property (assign, nonatomic) BOOL isBeautyOn;
@property (strong, nonatomic) AgoraBeautyOptions *beautyOptions;
@end

@implementation LiveRoomViewController
- (BOOL)isBroadcaster {
    return self.clientRole == AgoraClientRoleBroadcaster;
}

- (VideoViewLayouter *)viewLayouter {
    if (!_viewLayouter) {
        _viewLayouter = [[VideoViewLayouter alloc] init];
    }
    return _viewLayouter;
}

- (void)setClientRole:(AgoraClientRole)clientRole {
    _clientRole = clientRole;
    
    if (self.isBroadcaster) {
        self.shouldEnhancer = YES;
    }
    [self updateButtonsVisiablity];
}

- (void)setIsMuted:(BOOL)isMuted {
    _isMuted = isMuted;
  
    [self.rtcEngine muteLocalAudioStream:isMuted];
    [self.audioMuteButton setImage:[UIImage imageNamed:(isMuted ? @"btn_mute_cancel" : @"btn_mute")] forState:UIControlStateNormal];
}

- (void)setVideoSessions:(NSMutableArray<VideoSession *> *)videoSessions {
    _videoSessions = videoSessions;
    if (self.remoteContainerView) {
        [self updateInterfaceWithAnimation:YES];
    }
}

- (void)setFullSession:(VideoSession *)fullSession {
    _fullSession = fullSession;
    if (self.remoteContainerView) {
        [self updateInterfaceWithAnimation:YES];
    }
}

- (void)setIsEnableSuperResolution:(BOOL)isEnableSuperResolution {
    _isEnableSuperResolution = isEnableSuperResolution;
    [self.superResolutionButton setImage:[UIImage imageNamed:_isEnableSuperResolution ? @"btn_sr_blue" : @"btn_sr"] forState:UIControlStateNormal];
}

- (void)setHighPriorityRemoteUid:(NSUInteger)highPriorityRemoteUid {
    _highPriorityRemoteUid = highPriorityRemoteUid;
    for (VideoSession *session in self.videoSessions) {
        [self.rtcEngine enableRemoteSuperResolution:session.uid enabled:NO];
        [self.rtcEngine setRemoteUserPriority:session.uid type:AgoraUserPriorityNormal];
    }
    if (highPriorityRemoteUid != 0) {
        if (self.isEnableSuperResolution) {
            [self.rtcEngine enableRemoteSuperResolution:highPriorityRemoteUid enabled:YES];
        }
        [self.rtcEngine setRemoteUserPriority:highPriorityRemoteUid type:AgoraUserPriorityHigh];
    }
}

- (void)setIsBeautyOn:(BOOL)isBeautyOn {
    _isBeautyOn = isBeautyOn;
    [self.rtcEngine setBeautyEffectOptions:isBeautyOn options:self.beautyOptions];
    [self.beautyEffectButton setImage:[UIImage imageNamed:(isBeautyOn ? @"btn_beautiful_cancel" : @"btn_beautiful")] forState:UIControlStateNormal];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.videoSessions = [[NSMutableArray alloc] init];
    
    self.roomNameLabel.text = self.roomName;
    [self updateButtonsVisiablity];
    
    [self loadAgoraKit];
    
    self.beautyOptions = [[AgoraBeautyOptions alloc] init];
    self.beautyOptions.lighteningContrastLevel = AgoraLighteningContrastNormal;
    self.beautyOptions.lighteningLevel = 0.7;
    self.beautyOptions.smoothnessLevel = 0.5;
    self.beautyOptions.rednessLevel = 0.1;
    
    self.isBeautyOn = YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"roomVCPopBeautyList"]) {
        BeautyEffectTableViewController *vc = segue.destinationViewController;
        vc.isBeautyOn = self.isBeautyOn;
        vc.smoothness = self.beautyOptions.smoothnessLevel;
        vc.lightening = self.beautyOptions.lighteningLevel;
        vc.contrast = self.beautyOptions.lighteningContrastLevel;
        vc.redness = self.beautyOptions.rednessLevel;
        vc.delegate = self;
        vc.popoverPresentationController.delegate = self;
    }
}

- (IBAction)doSwitchCameraPressed:(UIButton *)sender {
    [self.rtcEngine switchCamera];
}

- (IBAction)doMutePressed:(UIButton *)sender {
    self.isMuted = !self.isMuted;
}

- (IBAction)doBroadcastPressed:(UIButton *)sender {
    if (self.isBroadcaster) {
        self.clientRole = AgoraClientRoleAudience;
        if (self.fullSession.uid == 0) {
            self.fullSession = nil;
        }
    } else {
        self.clientRole = AgoraClientRoleBroadcaster;
    }
    
    [self.rtcEngine setClientRole:self.clientRole];
    [self updateInterfaceWithAnimation:YES];
}

- (IBAction)doSuperResolutionPressed:(UIButton *)sender {
    self.isEnableSuperResolution = !self.isEnableSuperResolution;
    self.highPriorityRemoteUid = [self highPriorityRemoteUidInSessions:self.videoSessions fullSession:self.fullSession];
}

- (IBAction)doDoubleTapped:(UITapGestureRecognizer *)sender {
    if (!self.fullSession) {
        VideoSession *tappedSession = [self.viewLayouter responseSessionOfGesture:sender inSessions:self.videoSessions inContainerView:self.remoteContainerView];
        if (tappedSession) {
            self.fullSession = tappedSession;
        }
    } else {
        self.fullSession = nil;
    }
}

- (IBAction)doLeavePressed:(UIButton *)sender {
    [self leaveChannel];
}

- (void)updateButtonsVisiablity {
    [self.broadcastButton setImage:[UIImage imageNamed:self.isBroadcaster ? @"btn_join_cancel" : @"btn_join"] forState:UIControlStateNormal];
    for (UIButton *button in self.sessionButtons) {
        button.hidden = !self.isBroadcaster;
    }
}

- (IBAction)mirrorRemoteVideo:(UIButton *)sender {
    NSLog(@"mirrorRemoteVideo -------");
    self.isMirror = !self.isMirror;
    [self.rtcEngine setParameters:@"{\"che.video.local.render\":false}"]; // 本地预览保持不变
    if (self.isMirror) {
        [self.rtcEngine setLocalVideoMirrorMode:AgoraVideoMirrorModeDisabled];
        [AGVideoPreProcessing setMirrorVideo:YES];
        [sender setTitle:@"mirror" forState:UIControlStateNormal];
    }
    else {
        [self.rtcEngine setLocalVideoMirrorMode:AgoraVideoMirrorModeEnabled];
        [AGVideoPreProcessing setMirrorVideo:NO];
        [sender setTitle:@"unmirror" forState:UIControlStateNormal];
    }
    [self.rtcEngine setParameters:@"{\"che.video.local.render\":true}"]; // 本地预览保持不变
}

- (void)leaveChannel {
    [self setIdleTimerActive:YES];
    
    [self.rtcEngine setupLocalVideo:nil];
    [self.rtcEngine leaveChannel:nil];
    if (self.isBroadcaster) {
        [self.rtcEngine stopPreview];
    }
    
    [AGVideoPreProcessing deregisterVideoPreprocessing:self.rtcEngine];
    
    for (VideoSession *session in self.videoSessions) {
        [session.hostingView removeFromSuperview];
    }
    [self.videoSessions removeAllObjects];
    
    if ([self.delegate respondsToSelector:@selector(liveVCNeedClose:)]) {
        [self.delegate liveVCNeedClose:self];
    }
}

- (void)setIdleTimerActive:(BOOL)active {
    [UIApplication sharedApplication].idleTimerDisabled = !active;
}

- (void)alertString:(NSString *)string {
    if (!string.length) {
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:string preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateInterfaceWithAnimation:(BOOL)animation {
    if (animation) {
        [UIView animateWithDuration:0.3 animations:^{
            [self updateInterface];
            [self.view layoutIfNeeded];
        }];
    } else {
        [self updateInterface];
    }
}

- (void)updateInterface {
    NSArray *displaySessions;
    if (!self.isBroadcaster && self.videoSessions.count) {
        displaySessions = [self.videoSessions subarrayWithRange:NSMakeRange(1, self.videoSessions.count - 1)];
    } else {
        displaySessions = [self.videoSessions copy];
    }
    
    [self.viewLayouter layoutSessions:displaySessions fullSession:self.fullSession inContainer:self.remoteContainerView];
    [self setStreamTypeForSessions:displaySessions fullSession:self.fullSession];
    self.highPriorityRemoteUid = [self highPriorityRemoteUidInSessions:displaySessions fullSession:self.fullSession];
}

- (void)setStreamTypeForSessions:(NSArray<VideoSession *> *)sessions fullSession:(VideoSession *)fullSession {
    if (fullSession) {
        for (VideoSession *session in sessions) {
            if (session == self.fullSession) {
                [self.rtcEngine setRemoteVideoStream:fullSession.uid type:AgoraVideoStreamTypeHigh];
            } else {
                [self.rtcEngine setRemoteVideoStream:session.uid type:AgoraVideoStreamTypeLow];
            }
        }
    } else {
        for (VideoSession *session in sessions) {
            [self.rtcEngine setRemoteVideoStream:session.uid type:AgoraVideoStreamTypeHigh];
        }
    }
}

- (void)addLocalSession {
    VideoSession *localSession = [VideoSession localSession];
    [self.videoSessions addObject:localSession];
    [self.rtcEngine setupLocalVideo:localSession.canvas];
    [self updateInterfaceWithAnimation:YES];
}

- (VideoSession *)fetchSessionOfUid:(NSUInteger)uid {
    for (VideoSession *session in self.videoSessions) {
        if (session.uid == uid) {
            return session;
        }
    }
    return nil;
}

- (VideoSession *)videoSessionOfUid:(NSUInteger)uid {
    VideoSession *fetchedSession = [self fetchSessionOfUid:uid];
    if (fetchedSession) {
        return fetchedSession;
    } else {
        VideoSession *newSession = [[VideoSession alloc] initWithUid:uid];
        [self.videoSessions addObject:newSession];
        [self updateInterfaceWithAnimation:YES];
        return newSession;
    }
}

- (NSUInteger)highPriorityRemoteUidInSessions:(NSArray<VideoSession *> *)sessions fullSession:(VideoSession *)fullSession {
    if (fullSession) {
        return fullSession.uid;
    } else {
        return sessions.lastObject.uid;
    }
}

//MARK: - Agora Media SDK
- (void)loadAgoraKit {
    self.rtcEngine.delegate = self;
    [self.rtcEngine setChannelProfile:AgoraChannelProfileLiveBroadcasting];
    [AGVideoPreProcessing registerVideoPreprocessing:self.rtcEngine];
//    [self.rtcEngine enableDualStreamMode:YES];
    [self.rtcEngine enableVideo];
    
//    [self.rtcEngine setVideoProfile:self.videoProfile swapWidthAndHeight:YES];
    AgoraVideoEncoderConfiguration *configuration =
         [[AgoraVideoEncoderConfiguration alloc] initWithSize:self.videoProfile
                                                    frameRate:AgoraVideoFrameRateFps24
                                                      bitrate:AgoraVideoBitrateStandard
                                              orientationMode:AgoraVideoOutputOrientationModeAdaptative];
     [self.rtcEngine setVideoEncoderConfiguration:configuration];
    
    [self.rtcEngine setClientRole:self.clientRole];
    
    if (self.isBroadcaster) {
        [self.rtcEngine startPreview];
    }
    
    [self addLocalSession];
    
    int code = [self.rtcEngine joinChannelByToken:[KeyCenter Token] channelId:self.roomName info:nil uid:0 joinSuccess:nil];
    if (code == 0) {
        [self setIdleTimerActive:NO];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self alertString:[NSString stringWithFormat:@"Join channel failed: %d", code]];
        });
    }
    
    if (self.isBroadcaster) {
        self.shouldEnhancer = YES;
    }
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinedOfUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    VideoSession *userSession = [self videoSessionOfUid:uid];
    [self.rtcEngine setupRemoteVideo:userSession.canvas];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine firstLocalVideoFrameWithSize:(CGSize)size elapsed:(NSInteger)elapsed {
    if (self.videoSessions.count) {
        [self updateInterfaceWithAnimation:NO];
    }
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOfflineOfUid:(NSUInteger)uid reason:(AgoraUserOfflineReason)reason {
    VideoSession *deleteSession;
    for (VideoSession *session in self.videoSessions) {
        if (session.uid == uid) {
            deleteSession = session;
        }
    }
    
    if (deleteSession) {
        [self.videoSessions removeObject:deleteSession];
        [deleteSession.hostingView removeFromSuperview];
        [self updateInterfaceWithAnimation:YES];
        
        if (deleteSession == self.fullSession) {
            self.fullSession = nil;
        }
    }
}

//MARK: - enhancer
- (void)beautyEffectTableVCDidChange:(BeautyEffectTableViewController *)enhancerTableVC {
    self.beautyOptions.lighteningLevel = enhancerTableVC.lightening;
    self.beautyOptions.smoothnessLevel = enhancerTableVC.smoothness;
    self.beautyOptions.lighteningContrastLevel = enhancerTableVC.contrast;
    self.beautyOptions.rednessLevel = enhancerTableVC.redness;
    self.isBeautyOn = enhancerTableVC.isBeautyOn;
}

//MARK: - vc
- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller traitCollection:(UITraitCollection *)traitCollection {
    return UIModalPresentationNone;
}
@end
