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
#import "WGLUploadUtils.h"

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

+ (dispatch_queue_t)uploadQueue {
    static dispatch_queue_t dlQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dlQueue = dispatch_queue_create("com.wugl.mobile.uploadProvider.uploadQueue", DISPATCH_QUEUE_SERIAL);
    });
    return dlQueue;
}

#pragma mark - main interface

//上传入口
- (void)uploadWithFilePath:(NSString *)filePath {
    [self uploadWithFilePath:filePath start:nil progress:nil success:nil failure:nil cancel:nil];
}

- (void)uploadWithFilePath:(NSString *)filePath start:(WGLUploadProviderStartBlock)start progress:(WGLUploadProviderProgressBlock)progress success:(WGLUploadProviderSuccessBlock)success failure:(WGLUploadProviderFailBlock)failure cancel:(WGLUploadProviderCancelBlock)cancel {
    
    //已在任务队列中
    if ([self existInTasks:filePath]) {
        
        WGLUploadTask *findTask = [self taskForUrl:filePath];
        if (findTask) {
            if (findTask.uploadStatus == WGLUploadStatusWaiting
                && self.executeOrder == WGLUploadExeOrderLIFO) {
                //调整上传优先级
                
                Lock();
                [self.tasks removeObject:findTask];
                [self.tasks insertObject:findTask atIndex:0];
                Unlock();
                
                return;
            }
            else {
                //作为新的上传任务，重新上传
                Lock();
                [self.tasks removeObject:findTask];
                Unlock();
            }
        }
    }
    
    //限制任务数
    [self limitTasksSize];
    
    //添加到任务队列
    WGLUploadTask *task = [[WGLUploadTask alloc] init];
    task.filePath = filePath;
    task.uploadStatus = WGLUploadStatusWaiting;
    [self addTask:task];
    
    //触发下载
    [self startUpload];
    
}

//添加任务
- (void)addTask:(WGLUploadTask *)task {
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

//开始上传
- (void)startUpload {
    dispatch_async([WGLUploadProvider uploadQueue], ^{
        for (WGLUploader *uploader in self.uploaders) {
            //正在上传中
            if (uploader.fileOperation.uploadStatus == WGLUploadStatusUploading) {
                continue;
            }
            
            //获取等待上传的任务
            WGLUploadTask *task = [self preferredWaittingTask];
            if (task == nil) {
                //没有等待上传的任务
                break;
            }
            task.uploadStatus = WGLUploadStatusUploading;
            
            //归档：文件的上传信息
            [self recordUploadInfoIfNeed:task.filePath];
            
            //开始上传
            WGLFileStreamOperation *fileOperation = [[WGLFileStreamOperation alloc] initWithFilePath:task.filePath isReadOperation:YES];
            fileOperation.uploadStatus = WGLUploadStatusUploading;
            uploader.fileOperation = fileOperation;
            
            [uploader startUpload];
        }
    });
}

//取消所有的上传
- (void)cancelAllUploads {
    dispatch_async([WGLUploadProvider uploadQueue], ^{
        [self.uploaders enumerateObjectsUsingBlock:^(WGLUploader * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj cancelUpload];
            
            //TODO:
            WGLUploadTask *task = [self taskForUrl:obj.fileOperation.filePath];
            task.uploadStatus = WGLUploadStatusPaused;
        }];
    });
}

//取消指定上传
- (void)cancelUploadFilePath:(NSString *)filePath {
    if (!filePath
        || filePath.length == 0) {
        return;
    }
    dispatch_async([WGLUploadProvider uploadQueue], ^{
        [self.uploaders enumerateObjectsUsingBlock:^(WGLUploader * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj.fileOperation.filePath isEqualToString:filePath]) {
                [obj cancelUpload];
                
                //TODO:
                WGLUploadTask *task = [self taskForUrl:obj.fileOperation.filePath];
                task.uploadStatus = WGLUploadStatusPaused;
                *stop = YES;
            }
        }];
    });
}

#pragma mark - 信息归档

/**
 如果上传信息没有归档，则归档。
 防止上传被中止，下次启动app，可以从上一个已上传分片开始，断点续传，避免重复上传
 */
- (void)recordUploadInfoIfNeed:(NSString *)filePath {
    BOOL isRecord = [self isRecordUploadInfoForPath:filePath];
    if (NO == isRecord) {
        //尚未归档，则归档
        WGLFileStreamOperation *fileStream = [[WGLFileStreamOperation alloc] initWithFilePath:filePath isReadOperation:YES];
        BOOL success = [WGLUploadUtils archivedDataByAddFileStream:fileStream];
        if (NO == success) {
            NSLog(@"归档失败");
        }
    }
}

//判断当前文件的上传信息是否已归档
- (BOOL)isRecordUploadInfoForPath:(NSString *)filePath {
    WGLFileStreamOperation *fileStream = [WGLUploadUtils unArchivedFileStreamForFileName:filePath.lastPathComponent];
    if (fileStream) {
        return YES;
    }
    return NO;
}

#pragma mark - WGLUploaderDelegate

//获取上传URLRequest
- (NSMutableURLRequest *)uploaderGetUploadURLRequest:(WGLUploader *)uploader {
    NSMutableURLRequest *req = nil;
    if ([self.dataSource respondsToSelector:@selector(uploadProviderGetUploadURLRequest:)]) {
        req = [self.dataSource uploadProviderGetUploadURLRequest:self];
    }
    return req;
}

//获取请求body的part参数：name、fileName、mimeType
- (void)uploaderGetParamsForAppendPartData:(WGLUploader *)uploader handler:(WGLGetParamsForAppendPartDataHandler)handler {
    if ([self.dataSource respondsToSelector:@selector(uploadProviderGetParamsForAppendPartData:handler:)]) {
        [self.dataSource uploadProviderGetParamsForAppendPartData:self handler:handler];
    }
}

//获取文件上传之前的参数
- (void)uploaderGetParamsBeforeUpload:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo handler:(WGLGetFileParamsBeforeUploadHandler)handler {
    if ([self.dataSource respondsToSelector:@selector(uploadProviderGetParamsBeforeUpload:fileInfo:handler:)]) {
        [self.dataSource uploadProviderGetParamsBeforeUpload:self fileInfo:fileInfo handler:handler];
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

//上传开始
- (void)uploaderDidStart:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo {
    if ([self.delegate respondsToSelector:@selector(uploadProviderDidStart:fileInfo:)]) {
        [self.delegate uploadProviderDidStart:self fileInfo:fileInfo];
    }
}

//上传中
- (void)uploaderUploading:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo {
    if ([self.delegate respondsToSelector:@selector(uploadProviderUploading:fileInfo:)]) {
        [self.delegate uploadProviderUploading:self fileInfo:fileInfo];
    }
}

//上传成功
- (void)uploaderDidFinish:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo {
    WGLUploadTask *task = [self taskForUrl:uploader.fileOperation.filePath];
    task.uploadStatus = WGLUploadStatusFinished;
    
    if ([self.delegate respondsToSelector:@selector(uploadProviderDidFinish:fileInfo:)]) {
        [self.delegate uploadProviderDidFinish:self fileInfo:fileInfo];
    }
}

//上传失败
- (void)uploaderDidFailure:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo error:(NSError *)error {
    WGLUploadTask *task = [self taskForUrl:uploader.fileOperation.filePath];
    task.uploadStatus = WGLUploadStatusFailed;
    
    if ([self.delegate respondsToSelector:@selector(uploadProviderDidFailure:fileInfo:error:)]) {
        [self.delegate uploadProviderDidFailure:self fileInfo:fileInfo error:error];
    }
}

//上传取消
- (void)uploaderDidCancel:(WGLUploader *)uploader fileInfo:(WGLUploadFileInfo *)fileInfo {
    WGLUploadTask *task = [self taskForUrl:uploader.fileOperation.filePath];
    task.uploadStatus = WGLUploadStatusPaused;
    
    if ([self.delegate respondsToSelector:@selector(uploadProviderDidCancel:fileInfo:)]) {
        [self.delegate uploadProviderDidCancel:self fileInfo:fileInfo];
    }
}

#pragma mark - private

//已在任务队列
- (BOOL)existInTasks:(NSString *)filePath {
    __block BOOL exist = NO;
    Lock();
    [self.tasks enumerateObjectsUsingBlock:^(WGLUploadTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.filePath isEqualToString:filePath]) {
            exist = YES;
            *stop = YES;
        }
    }];
    Unlock();
    return exist;
}

//获取filePath对应的任务
- (WGLUploadTask *)taskForUrl:(NSString *)filePath {
    __block WGLUploadTask *task = nil;
    Lock();
    [self.tasks enumerateObjectsUsingBlock:^(WGLUploadTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.filePath isEqualToString:filePath]) {
            task = obj;
            *stop = YES;
        }
    }];
    Unlock();
    return task;
}

//限制任务数
- (void)limitTasksSize {
    if (self.maxUploadCount == -1) {
        //不受限制
        return;
    }
    if (self.tasks.count <= self.maxUploadCount) {
        return;
    }
    Lock();
    while (self.tasks.count > self.maxUploadCount) {
        [self.tasks removeLastObject];
    }
    Unlock();
}

//获取等待上传的任务
- (WGLUploadTask *)preferredWaittingTask {
    WGLUploadTask *findTask = nil;
    Lock();
    for (WGLUploadTask *task in self.tasks) {
        if (task.uploadStatus == WGLUploadStatusWaiting) {
            findTask = task;
        }
    }
    Unlock();
    return findTask;
}


@end
