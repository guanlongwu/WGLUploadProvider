//
//  WGLUploadHead.h
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/24.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#ifndef WGLUploadHead_h
#define WGLUploadHead_h

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

#endif /* WGLUploadHead_h */
