//
//  WGLUploader.h
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/24.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WGLFileStreamOperation.h"
#import "WGLUploadFileInfo.h"
#import "WGLUploader.h"
#import "WGLUploadHead.h"
@protocol WGLUploaderDataSource;
@protocol WGLUploaderDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface WGLUploader : NSObject
@property (nonatomic, weak) id <WGLUploaderDataSource> dataSource;
@property (nonatomic, weak) id <WGLUploaderDelegate> delegate;
@property (nonatomic, strong) WGLFileStreamOperation *fileOperation;//文件操作器

//开始上传
- (void)startUpload;

//取消上传
- (void)cancelUpload;

@end


@protocol WGLUploaderDataSource <NSObject>

/**
 获取文件上传的NSMutableURLRequest对象

 @param uploader WGLUploader
 @return 上传的NSMutableURLRequest对象
 */
- (NSMutableURLRequest *)uploaderGetUploadURLRequest:(WGLUploader *)uploader;

/**
 获取请求body的part参数：name、fileName、mimeType

 @param uploader WGLUploader
 @param handler 回调
 */
- (void)uploaderGetParamsForAppendPartData:(WGLUploader *)uploader handler:(WGLGetParamsForAppendPartDataHandler)handler;

/**
 异步获取上传文件所需的参数（note：这是文件上传之前的操作）

 @param uploader WGLUploader
 @param fileInfo 待上传文件的信息
 @param handler 回调
 */
- (void)uploaderGetParamsBeforeUpload:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo handler:(WGLGetFileParamsBeforeUploadHandler)handler;

/**
 获取上传每个分片文件所需的参数（note：这是分片文件上传时的操作）

 @param uploader WGLUploader
 @param params 上传文件之前，获取到的参数（最终需要的参数，应该是带上这里的参数）
 @param chunkIndex 当前正在上传的文件分片下标
 @return 上传操作的参数
 */
- (NSDictionary *)uploaderGetChunkUploadParams:(WGLUploader *)uploader params:(NSDictionary *)params chunkIndex:(NSInteger)chunkIndex;

@end


@protocol WGLUploaderDelegate <NSObject>

//上传开始
- (void)uploaderDidStart:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo;

//上传中
- (void)uploaderUploading:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo;

//上传成功
- (void)uploaderDidFinish:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo;

//上传失败
- (void)uploaderDidFailure:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo error:(NSError *)error;

//上传取消
- (void)uploaderDidCancel:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo;

@end

NS_ASSUME_NONNULL_END
