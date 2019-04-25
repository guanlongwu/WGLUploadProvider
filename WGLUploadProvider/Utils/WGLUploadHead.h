//
//  WGLUploadHead.h
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/24.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#ifndef WGLUploadHead_h
#define WGLUploadHead_h
@class WGLUploadProvider;

typedef NS_ENUM(NSInteger, WGLUploadExeOrder) {
    // 以队列的方式，按照先进先出的顺序上传。这是默认的上传顺序
    WGLUploadExeOrderFIFO,
    // 以栈的方式，按照后进先出的顺序上传。（以添加操作依赖的方式实现）
    WGLUploadExeOrderLIFO
};

//任务状态
typedef NS_ENUM(NSInteger, WGLUploadStatus) {
    WGLUploadStatusWaiting = 0, //任务队列等待
    WGLUploadStatusUploading,   //上传中
    WGLUploadStatusPaused,      //暂停
    WGLUploadStatusFinished,    //上传成功
    WGLUploadStatusFailed       //上传失败
};

//下载中回调
typedef void(^WGLUploadProviderProgressBlock)(WGLUploadProvider *ulProvider, NSString *_urlString, uint64_t receiveLength, uint64_t totalLength);

//下载成功回调
typedef void(^WGLUploadProviderSuccessBlock)(WGLUploadProvider *ulProvider, NSString *_urlString, NSString *filePath);

//下载失败回调
typedef void(^WGLUploadProviderFailBlock)(WGLUploadProvider *ulProvider, NSString *_urlString);

//下载开始回调
typedef void(^WGLUploadProviderStartBlock)(WGLUploadProvider *ulProvider, NSString *_urlString);

#endif /* WGLUploadHead_h */
