//
//  WGLUploadProvider.m
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/23.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import "WGLUploadProvider.h"
#import "WGLUploadTask.h"
#import "WGLUploader.h"

#define Lock() dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER)
#define Unlock() dispatch_semaphore_signal(self->_lock)

@interface WGLUploadProvider (){
    dispatch_semaphore_t _lock;
}
@property (nonatomic, strong) NSMutableArray <WGLUploadTask *> *tasks;//任务队列
@property (nonatomic, strong) NSMutableArray <WGLUploader *> *uploaders; //上传队列

@end

@implementation WGLUploadProvider

#pragma mark - init

+ (instancetype)sharedProvider {
    static WGLUploadProvider *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[[self class] alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _lock = dispatch_semaphore_create(1);
        _maxUploadCount = -1;
        _executeOrder = WGLUploadExeOrderFIFO;
        
        _tasks = [[NSMutableArray alloc] init];
        _uploaders = [NSMutableArray array];
        [self setMaxConcurrentUploadCount:2];
    }
    return self;
}

- (void)setMaxConcurrentUploadCount:(NSInteger)maxConcurrentUploadCount {
    if (_maxConcurrentUploadCount != maxConcurrentUploadCount) {
        _maxConcurrentUploadCount = maxConcurrentUploadCount;
        
        //创建上传器队列
        for (int i = 0; i < maxConcurrentUploadCount; i++) {
            WGLUploader *uploader = [[WGLUploader alloc] init];
            uploader.dataSource = (id<WGLUploaderDataSource>)self;
            uploader.delegate = (id<WGLUploaderDelegate>)self;
            [self.uploaders addObject:uploader];
        }
    }
}

#pragma mark - main interface

//上传入口
- (void)uploadWithFilePath:(NSString *)filePath {
    
}

//添加任务
- (void)addTasks:(WGLUploadTask *)task {
    if (!task) {
        return;
    }
    Lock();
    if (self.executeOrder == WGLUploadExeOrderFIFO) {
        [self.tasks addObject:task];
    }
    else if (self.executeOrder == WGLUploadExeOrderLIFO) {
        [self.tasks insertObject:task atIndex:0];
    }
    else {
        [self.tasks addObject:task];
    }
    Unlock();
}

#pragma mark - WGLUploaderDelegate

//获取上传URLRequest
- (NSURLRequest *)uploaderGetUploadURLRequest:(WGLUploader *)uploader {
    NSURLRequest *req = nil;
    if ([self.dataSource respondsToSelector:@selector(uploadProviderGetUploadURLRequest:)]) {
        req = [self.dataSource uploadProviderGetUploadURLRequest:self];
    }
    return req;
}

//获取文件上传之前的参数
- (void)uploaderGetParamsBeforeUpload:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo completion:(WGLGetFileParamsBeforeUploadCompletion)completion {
    if ([self.dataSource respondsToSelector:@selector(uploadProviderGetParamsBeforeUpload:fileInfo:completion:)]) {
        [self.dataSource uploadProviderGetParamsBeforeUpload:self fileInfo:fileInfo completion:completion];
    }
}

//获取每个分片文件上传的参数
- (NSDictionary *)uploaderGetChunkUploadParams:(WGLUploader *)uploader params:(NSDictionary *)params chunkIndex:(NSInteger)chunkIndex {
    NSDictionary *uploadParams = nil;
    if ([self.dataSource respondsToSelector:@selector(uploadProviderGetChunkUploadParams:params:chunkIndex:)]) {
        uploadParams = [self.dataSource uploadProviderGetChunkUploadParams:self params:params chunkIndex:chunkIndex];
    }
    return uploadParams;
}

//上传中
- (void)uploaderUploading:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo {
    if ([self.delegate respondsToSelector:@selector(uploadProviderUploading:fileInfo:)]) {
        [self.delegate uploadProviderUploading:self fileInfo:fileInfo];
    }
}

//上传成功
- (void)uploaderDidFinish:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo {
    if ([self.delegate respondsToSelector:@selector(uploadProviderDidFinish:fileInfo:)]) {
        [self.delegate uploadProviderDidFinish:self fileInfo:fileInfo];
    }
}

//上传失败
- (void)uploaderDidFailure:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo error:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(uploadProviderDidFailure:fileInfo:error:)]) {
        [self.delegate uploadProviderDidFailure:self fileInfo:fileInfo error:error];
    }
}

//上传取消
- (void)uploaderDidCancel:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo {
    if ([self.delegate respondsToSelector:@selector(uploadProviderDidCancel:fileInfo:)]) {
        [self.delegate uploadProviderDidCancel:self fileInfo:fileInfo];
    }
}


@end
