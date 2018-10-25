#include <jni.h>
#include <android/log.h>
#include <cstring>
#include <agora/AgoraBase.h>

#include "agora/IAgoraRtcEngine.h"
#include "agora/IAgoraMediaEngine.h"

#include "video_preprocessing_plugin_jni.h"


//add by longxin@agora.io
#include "../include/libyuv.h"
#include <vector>
#include <stdio.h>
#include <sys/time.h>
//打印当前时间戳
long getCurrentTime()
{
    struct timeval tv;
    gettimeofday(&tv,NULL);
    return tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

//int main()
//{
//    printf("c/c++ program:%ld\n",getCurrentTime());
//    return 0;
//}


using namespace libyuv;

jboolean mFrontCameraRemoteMirror = true;

//add by longxin@agora.io
class AgoraVideoFrameObserver : public agora::media::IVideoFrameObserver
{
public:
    virtual bool onCaptureVideoFrame(VideoFrame& videoFrame) override
    {
        int width = videoFrame.width;
        int height = videoFrame.height;
          //add by longxin@agora.io
        long begin = getCurrentTime();
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

        long interval  = getCurrentTime() - begin;
        __android_log_print(ANDROID_LOG_INFO, "longxin","----YUVmirror time %ld", interval);

//        printf("----YUVmirror time :%ld\n",(end - begin));

        //add by longxin@agora.io
        return true;
	}

    virtual bool onRenderVideoFrame(unsigned int uid, VideoFrame& videoFrame) override
    {
        return true;
    }

        //add by longxin@agora.io
private:
    std::vector<unsigned char> m_yBuffer;
    std::vector<unsigned char> m_uBuffer;
    std::vector<unsigned char> m_vBuffer;
        //add by longxin@agora.io
};

static AgoraVideoFrameObserver s_videoFrameObserver;
static agora::rtc::IRtcEngine* rtcEngine = NULL;

#ifdef __cplusplus
extern "C" {
#endif

int __attribute__((visibility("default"))) loadAgoraRtcEnginePlugin(agora::rtc::IRtcEngine* engine)
{
    __android_log_print(ANDROID_LOG_ERROR, "plugin", "plugin loadAgoraRtcEnginePlugin");
    rtcEngine = engine;
    return 0;
}

void __attribute__((visibility("default"))) unloadAgoraRtcEnginePlugin(agora::rtc::IRtcEngine* engine)
{
    __android_log_print(ANDROID_LOG_ERROR, "plugin", "plugin unloadAgoraRtcEnginePlugin");
    rtcEngine = NULL;
}

JNIEXPORT void JNICALL Java_io_agora_preprocessing_VideoPreProcessing_enablePreProcessing
  (JNIEnv *env, jobject obj, jboolean enable)
{
    if (!rtcEngine)
        return;
    agora::util::AutoPtr<agora::media::IMediaEngine> mediaEngine;
    mediaEngine.queryInterface(rtcEngine, agora::AGORA_IID_MEDIA_ENGINE);
    if (mediaEngine) {
        if (enable) {
            mediaEngine->registerVideoFrameObserver(&s_videoFrameObserver);
        } else {
            mediaEngine->registerVideoFrameObserver(NULL);
        }
    }
}

#ifdef __cplusplus
}
#endif
