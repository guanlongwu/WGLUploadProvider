//
//  WGLUploader.h
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/24.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WGLFileStreamOperation.h"
@protocol WGLUploaderDataSource;
@protocol WGLUploaderDelegate;
@class WGLUploader;

NS_ASSUME_NONNULL_BEGIN

//获取上传文件的参数Block
typedef void(^WGLGetFileParamsBeforeUploadCompletion)(WGLUploader *uploader, NSDictionary *params);

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
 获取文件上传的NSURLRequest对象

 @param uploader WGLUploader
 @return 上传的NSURLRequest对象
 */
- (NSURLRequest *)uploaderGetUploadURLRequest:(WGLUploader *)uploader;

/**
 在上传文件之前，需要获取一些参数
 note：这是上传之前的操作

 @param uploader WGLUploader
 @param fileOperation 文件流操作类
 @param completion 回调
 */
- (void)uploaderGetParamsBeforeUpload:(WGLUploader *)uploader fileOperation:(WGLFileStreamOperation *)fileOperation completion:(WGLGetFileParamsBeforeUploadCompletion)completion;

/**
 执行上传时，需要的参数
 note：这是上传时的操作

 @param uploader WGLUploader
 @param streamFragments 文件分片数组
 @param segmentIndex 当前正在上传的文件分片下标
 @param params 上传文件之前，获取到的参数（最终需要的参数，应该是带上这里的参数）
 @return 上传操作的参数
 */
- (NSDictionary *)uploaderGetUploadParams:(WGLUploader *)uploader streamFragments:(NSArray <WGLStreamFragment*> *)streamFragments segmentIndex:(NSInteger)segmentIndex params:(NSDictionary *)params;

@end


@protocol WGLUploaderDelegate <NSObject>

//上传中
- (void)uploaderUploading:(WGLUploader *)uploader fileOperation:(WGLFileStreamOperation *)fileOperation;

//上传成功
- (void)uploaderDidFinish:(WGLUploader *)uploader fileOperation:(WGLFileStreamOperation *)fileOperation;

//上传失败
- (void)uploaderDidFailure:(WGLUploader *)uploader fileOperation:(WGLFileStreamOperation *)fileOperation error:(NSError *)error;

//上传取消
- (void)uploaderDidCancel:(WGLUploader *)uploader fileOperation:(WGLFileStreamOperation *)fileOperation;

@end

NS_ASSUME_NONNULL_END
