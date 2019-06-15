//
//  WGLUploadProvider.h
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/23.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WGLUploadHead.h"
#import "WGLUploadFileInfo.h"
@protocol WGLUploadProviderDataSource;
@protocol WGLUploadProviderDelegate;
@class WGLUploadProvider;

NS_ASSUME_NONNULL_BEGIN

//获取上传文件的参数Block
typedef void(^WGLGetFileParamsBeforeUploadCompletion)(WGLUploadProvider *ulProvider, NSDictionary *params);

@interface WGLUploadProvider : NSObject
@property (nonatomic, weak) id <WGLUploadProviderDataSource> dataSource;
@property (nonatomic, weak) id <WGLUploadProviderDelegate> delegate;

+ (instancetype)sharedProvider;

/**
 最大支持上传数
 默认-1，表示不进行限制
 */
@property (nonatomic, assign) NSInteger maxUploadCount;

/**
 最大并发上传数
 默认2
 */
@property (nonatomic, assign) NSInteger maxConcurrentUploadCount;

/**
 上传优先级
 默认先进先出
 */
@property (nonatomic, assign) WGLUploadExeOrder executeOrder;

/**
 开始上传
 
 @param filePath 上传文件的路径
 */
- (void)uploadWithFilePath:(NSString *)filePath;

- (void)uploadWithFilePath:(NSString *)filePath start:(WGLUploadProviderStartBlock)start progress:(WGLUploadProviderProgressBlock)progress success:(WGLUploadProviderSuccessBlock)success failure:(WGLUploadProviderFailBlock)failure cancel:(WGLUploadProviderCancelBlock)cancel;

//取消所有的上传
- (void)cancelAllUploads;

//取消指定上传
- (void)cancelUploadFilePath:(NSString *)filePath;

@end


@protocol WGLUploadProviderDataSource <NSObject>

/**
 获取文件上传的NSURLRequest对象
 
 @param ulProvider WGLUploadProvider
 @return 上传的NSURLRequest对象
 */
- (NSURLRequest *)uploadProviderGetUploadURLRequest:(WGLUploadProvider *)ulProvider;

/**
 异步获取上传文件所需的参数（note：这是文件上传之前的操作）
 
 @param ulProvider WGLUploadProvider
 @param fileInfo 待上传文件的信息
 @param completion 回调
 */
- (void)uploadProviderGetParamsBeforeUpload:(WGLUploadProvider *)ulProvider fileInfo:(WGLUploadFileInfo *)fileInfo completion:(WGLGetFileParamsBeforeUploadCompletion)completion;

/**
 获取上传每个分片文件所需的参数（note：这是分片文件上传时的操作）
 
 @param ulProvider WGLUploadProvider
 @param params 上传文件之前，获取到的参数（最终需要的参数，应该是带上这里的参数）
 @param chunkIndex 当前正在上传的文件分片下标
 @return 上传操作的参数
 */
- (NSDictionary *)uploadProviderGetChunkUploadParams:(WGLUploadProvider *)ulProvider params:(NSDictionary *)params chunkIndex:(NSInteger)chunkIndex;

@end


@protocol WGLUploadProviderDelegate <NSObject>

//下载开始
- (void)uploadProviderDidStart:(WGLUploadProvider *)ulProvider fileInfo:(WGLUploadFileInfo *)fileInfo;

//上传中
- (void)uploadProviderUploading:(WGLUploadProvider *)ulProvider fileInfo:(WGLUploadFileInfo *)fileInfo;

//上传成功
- (void)uploadProviderDidFinish:(WGLUploadProvider *)ulProvider fileInfo:(WGLUploadFileInfo *)fileInfo;

//上传失败
- (void)uploadProviderDidFailure:(WGLUploadProvider *)ulProvider fileInfo:(WGLUploadFileInfo *)fileInfo error:(NSError *)error;

//上传取消
- (void)uploadProviderDidCancel:(WGLUploadProvider *)ulProvider fileInfo:(WGLUploadFileInfo *)fileInfo;

@end

NS_ASSUME_NONNULL_END
