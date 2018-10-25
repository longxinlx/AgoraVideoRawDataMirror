LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
# libyuv
LOCAL_MODULE := yuv
$(warning "------华丽的分割线----------")
$(warning "the value of TARGET_ARCH_ABI is$(TARGET_ARCH_ABI)")
LOCAL_SRC_FILES := ../PREBUILT/$(TARGET_ARCH_ABI)/libyuv.a
include $(PREBUILT_STATIC_LIBRARY)
#必须clear vars 否则又编译了 一个libyuv的so
include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
	video_preprocessing_plugin_jni.cpp \

# The JNI headers
LOCAL_C_INCLUDES += \
    	$(LOCAL_PATH)/include \

LOCAL_STATIC_LIBRARIES := yuv

LOCAL_LDLIBS := -ldl -llog

LOCAL_MODULE := apm-plugin-video-preprocessing

include $(BUILD_SHARED_LIBRARY)
