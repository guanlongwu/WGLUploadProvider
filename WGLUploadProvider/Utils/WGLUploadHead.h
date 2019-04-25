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
@class WGLUploadFileInfo;

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

//下载开始回调
typedef void(^WGLUploadProviderStartBlock)(WGLUploadProvider *ulProvider, WGLUploadFileInfo *fileInfo);

//下载中回调
typedef void(^WGLUploadProviderProgressBlock)(WGLUploadProvider *ulProvider, WGLUploadFileInfo *fileInfo);

//下载成功回调
typedef void(^WGLUploadProviderSuccessBlock)(WGLUploadProvider *ulProvider, WGLUploadFileInfo *fileInfo);

//下载失败回调
typedef void(^WGLUploadProviderFailBlock)(WGLUploadProvider *ulProvider, WGLUploadFileInfo *fileInfo, NSError *error);

//下载取消回调
typedef void(^WGLUploadProviderCancelBlock)(WGLUploadProvider *ulProvider, WGLUploadFileInfo *fileInfo);

#endif /* WGLUploadHead_h */
