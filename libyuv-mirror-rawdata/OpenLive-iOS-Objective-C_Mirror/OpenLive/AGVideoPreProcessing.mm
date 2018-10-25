//
//  AGVideoPreProcessing.m
//  OpenVideoCall
//
//  Created by Alex Zheng on 7/28/16.
//  Copyright © 2016 Agora.io All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AGVideoPreProcessing.h"

#import <AgoraRtcEngineKit/AgoraRtcEngineKit.h>
#import <AgoraRtcEngineKit/IAgoraRtcEngine.h>
#import <AgoraRtcEngineKit/IAgoraMediaEngine.h>

#include "libyuv.h"
#include <vector>

class AgoraVideoFrameObserver : public agora::media::IVideoFrameObserver
{
public:
    AgoraVideoFrameObserver()
    {
        bMirrorVideo = NO;
    }
    
    ~AgoraVideoFrameObserver()
    {
    }
    
    virtual bool onCaptureVideoFrame(VideoFrame& videoFrame) override
    {
        if (bMirrorVideo) {
            UInt64 recordTime1 = [[NSDate date] timeIntervalSince1970]*1000;

            int yBufferSize = videoFrame.yStride * videoFrame.height;
            if (yBufferSize > m_yBuffer.size()) {
                m_yBuffer.resize(yBufferSize);
            }
            
            int uBufferSize = videoFrame.uStride * videoFrame.height / 2;
            if (uBufferSize > m_uBuffer.size()) {
                m_uBuffer.resize(uBufferSize);
            }
            
            int vBufferSize = videoFrame.vStride * videoFrame.height / 2;
            if (vBufferSize > m_vBuffer.size()) {
                m_vBuffer.resize(vBufferSize);
            }
            
            if (videoFrame.rotation == 0 || videoFrame.rotation == 180) {
                libyuv::I420Mirror((const unsigned char *)videoFrame.yBuffer, videoFrame.yStride,
                                   (const unsigned char *)videoFrame.uBuffer, videoFrame.uStride,
                                   (const unsigned char *)videoFrame.vBuffer, videoFrame.vStride,
                                   &m_yBuffer[0], videoFrame.yStride,
                                   &m_uBuffer[0], videoFrame.uStride,
                                   &m_vBuffer[0], videoFrame.vStride,
                                   videoFrame.width, videoFrame.height);
            }
            else {
                libyuv::I420Copy((const unsigned char *)videoFrame.yBuffer, videoFrame.yStride,
                                 (const unsigned char *)videoFrame.uBuffer, videoFrame.uStride,
                                 (const unsigned char *)videoFrame.vBuffer, videoFrame.vStride,
                                 &m_yBuffer[0], videoFrame.yStride,
                                 &m_uBuffer[0], videoFrame.uStride,
                                 &m_vBuffer[0], videoFrame.vStride,
                                 videoFrame.width, -videoFrame.height);
            }
            
            memcpy(videoFrame.yBuffer, &m_yBuffer[0], yBufferSize);
            memcpy(videoFrame.uBuffer, &m_uBuffer[0], uBufferSize);
            memcpy(videoFrame.vBuffer, &m_vBuffer[0], vBufferSize);
            UInt64 recordTime2 = [[NSDate date] timeIntervalSince1970]*1000;
            NSLog(@"--------mirror time: %lld", (recordTime2 - recordTime1));
        }
        return true;
    }
    
    virtual bool onRenderVideoFrame(unsigned int uid, VideoFrame& videoFrame) override
    {
        return true;
    }

    void setMirrorVideo(BOOL _bMirror){
        bMirrorVideo = _bMirror ;
    }
    
private:
    BOOL bMirrorVideo ;
    std::vector<unsigned char> m_yBuffer;
    std::vector<unsigned char> m_uBuffer;
    std::vector<unsigned char> m_vBuffer;
};

static AgoraVideoFrameObserver s_videoFrameObserver;

@implementation AGVideoPreProcessing


+(int)registerVideoPreprocessing: (AgoraRtcEngineKit*) kit
{
    if (!kit) {
        return -1;
    }
    agora::rtc::IRtcEngine* rtc_engine = (agora::rtc::IRtcEngine*)kit.getNativeHandle;
    agora::util::AutoPtr<agora::media::IMediaEngine> mediaEngine;
    mediaEngine.queryInterface(rtc_engine, agora::AGORA_IID_MEDIA_ENGINE);
    if (mediaEngine)
    {
        
        mediaEngine->registerVideoFrameObserver(&s_videoFrameObserver);
    }
    return 0;
}

+ (void)setMirrorVideo:(BOOL)bMirror
{
    s_videoFrameObserver.setMirrorVideo(bMirror);
}
+(int)deregisterVideoPreprocessing: (AgoraRtcEngineKit*) kit
{
    if (!kit) {
        return -1;
    }
    
    agora::rtc::IRtcEngine* rtc_engine = (agora::rtc::IRtcEngine*)kit.getNativeHandle;
    agora::util::AutoPtr<agora::media::IMediaEngine> mediaEngine;
    mediaEngine.queryInterface(rtc_engine, agora::AGORA_IID_MEDIA_ENGINE);
    if (mediaEngine)
    {
        mediaEngine->registerVideoFrameObserver(NULL);
    }
    return 0;
}
@end
