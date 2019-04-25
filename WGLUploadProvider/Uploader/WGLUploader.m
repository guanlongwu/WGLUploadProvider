//
//  WGLUploader.m
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/24.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import "WGLUploader.h"

//分隔符
#define Boundary @"1a2b3c"
//一般换行
#define Wrap1 @"\r\n"
//key-value换行
#define Wrap2 @"\r\n\r\n"
//开始分割
#define StartBoundary [NSString stringWithFormat:@"--%@%@", Boundary, Wrap1]
//文件分割完成
#define EndBody [NSString stringWithFormat:@"--%@--", Boundary]

//一个片段上传失败默认重试3次
#define REPEAT_MAX 3

@interface WGLUploader ()
@property (nonatomic, strong) NSMutableDictionary *fileUploadParams;//文件上传参数
@property (nonatomic, strong) NSURLSessionUploadTask *currentUploadTask;//当前上传核心类

@property (nonatomic, assign) BOOL isUserSuspended;//用户是否已暂停上传
@property (nonatomic, assign) NSInteger uploadRepeatNum;//上传重试次数
@end

@implementation WGLUploader

#pragma mark - init

- (instancetype)init {
    if (self = [super init]) {
        [self initData];
    }
    return self;
}

- (void)initData {
    _isUserSuspended = NO;
    _uploadRepeatNum = 0;
}

- (void)setFileOperation:(WGLFileStreamOperation *)fileOperation {
    _fileOperation = fileOperation;
    _fileOperation.uploadStatus = WGLUploadStatusWaiting;
}

#pragma mark - 上传

//开始上传文件
- (void)startUpload {
    self.isUserSuspended = NO;
    
    if (self.fileUploadParams) {
        //开始上传
        
        [self uploadFileWithIndex:0 streamFragments:self.fileOperation.streamFragments];
    }
    else {
        //上传之前先获取参数
        
        WGLUploaderGetFileParamsBeforeUploadCompletion completion = ^(WGLUploader *uploader, NSDictionary *params) {
            //获取到参数
            uploader.fileUploadParams = [NSMutableDictionary dictionaryWithDictionary:params];
            //执行上传
            [uploader startUpload];
        };
        
        //获取参数的操作由代理实现
        WGLUploadFileInfo *fileInfo = [self getUploadFileInfo:self.fileOperation];
        if ([self.dataSource respondsToSelector:@selector(uploaderGetParamsBeforeUpload:fileInfo:completion:)]) {
            [self.dataSource uploaderGetParamsBeforeUpload:self fileInfo:fileInfo completion:completion];
        }
        else {
            NSLog(@"尚未获取上传参数，不能执行文件的上传！");
        }
    }
}

//依次上传分片文件
- (void)uploadFileWithIndex:(NSInteger)index streamFragments:(NSArray <WGLStreamFragment *> *)streamFragments {
    if (streamFragments.count == 0) {
        return;
    }
    if (index >= streamFragments.count) {
        
        self.fileOperation.uploadStatus = WGLUploadStatusFinished;
        [self archerFileUploadInfo];
        
        //回调：上传完成
        WGLUploadFileInfo *fileInfo = [self getUploadFileInfo:self.fileOperation];
        if ([self.delegate respondsToSelector:@selector(uploaderDidFinish:fileInfo:)]) {
            [self.delegate uploaderDidFinish:self fileInfo:fileInfo];
        }
        
        [self deallocSession];
        return;
    }
    
    WGLStreamFragment *streamFragment = streamFragments[index];
    
    if (streamFragment.isUploadSuccess) {
        //当前分片已上传，依次上传下一个分片
        
        [self uploadFileWithIndex:index+1 streamFragments:streamFragments];
        return;
    }
    @autoreleasepool {
        //获取上传参数
        NSDictionary *uploadParams = [self getChunkFileUploadParams:index];
        
        //获取上传文件data
        NSData *uploadData = [self.fileOperation readDataOfFragment:streamFragment];
        
        //开始上传
        __weak typeof(self) weakSelf = self;
        [self uploadTaskWithParams:uploadParams uploadData:uploadData completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (!error && httpResponse.statusCode == 200) {
                //上传成功
                
                strongSelf.uploadRepeatNum = 0;
                streamFragment.isUploadSuccess = YES;
                strongSelf.fileOperation.uploadStatus = WGLUploadStatusUploading;
                [strongSelf archerFileUploadInfo];
                
                //回调：上传中
                WGLUploadFileInfo *fileInfo = [self getUploadFileInfo:self.fileOperation];
                if ([self.delegate respondsToSelector:@selector(uploaderUploading:fileInfo:)]) {
                    [self.delegate uploaderUploading:self fileInfo:fileInfo];
                }
                
                //依次上传下一个分片
                [self uploadFileWithIndex:index+1 streamFragments:streamFragments];
                
            }
            else {
                //上传失败
                
                if (strongSelf.uploadRepeatNum < REPEAT_MAX) {
                    //重试
                    
                    strongSelf.uploadRepeatNum++;
                    [strongSelf uploadFileWithIndex:index streamFragments:streamFragments];
                }
                else {
                    strongSelf.fileOperation.uploadStatus = WGLUploadStatusFailed;
                    
                    //回调：上传失败
                    WGLUploadFileInfo *fileInfo = [self getUploadFileInfo:self.fileOperation];
                    if ([self.delegate respondsToSelector:@selector(uploaderDidFailure:fileInfo:error:)]) {
                        [self.delegate uploaderDidFailure:self fileInfo:fileInfo error:error];
                    }
                    
                    //停止上传
                    [strongSelf deallocSession];
                }

            }
        }];
    }
}

//上传的核心方法
-(void)uploadTaskWithParams:(NSDictionary *)params uploadData:(NSData *)data completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    if (self.isUserSuspended){
        [self cancelUpload];
        return;
    }
    NSURLRequest *req = [self getUploadRequest];
    NSData *formData = [self getHTTPBodyDataWithParams:params uploadData:data];
    self.currentUploadTask = [[NSURLSession sharedSession] uploadTaskWithRequest:req fromData:formData completionHandler:completionHandler];
    [self.currentUploadTask resume];
}

#pragma mark - 取消上传

- (void)cancelUpload {
    self.isUserSuspended = YES;
    
    //记录当前操作状态：取消/暂停
    self.fileOperation.uploadStatus = WGLUploadStatusPaused;
    
    //归档当前文件的上传状态：下次启动app可重新上传
    [self archerFileUploadInfo];
    
    //回调：取消上传
    WGLUploadFileInfo *fileInfo = [self getUploadFileInfo:self.fileOperation];
    if ([self.delegate respondsToSelector:@selector(uploaderDidCancel:fileInfo:)]) {
        [self.delegate uploaderDidCancel:self fileInfo:fileInfo];
    }
    
    //执行暂停取消
    if (self.currentUploadTask) {
        [self.currentUploadTask suspend];
        [self.currentUploadTask cancel];
        self.currentUploadTask = nil;
    }
}

- (void)deallocSession {
    self.fileUploadParams = nil;
    self.uploadRepeatNum = 0;
    self.currentUploadTask = nil;
    [[NSURLSession sharedSession] finishTasksAndInvalidate];
}

#pragma mark - 信息归档

- (void)archerFileUploadInfo {
    
}

#pragma mark - private

//获取上传request
- (NSURLRequest *)getUploadRequest {
    NSURLRequest *req = nil;
    if ([self.dataSource respondsToSelector:@selector(uploaderGetUploadURLRequest:)]) {
        req = [self.dataSource uploaderGetUploadURLRequest:self];
    }
    return req;
}

//获取分片上传的params
- (NSDictionary *)getChunkFileUploadParams:(NSInteger)index {
    NSDictionary *tmps = nil;
    if ([self.dataSource respondsToSelector:@selector(uploaderGetChunkUploadParams:params:chunkIndex:)]) {
        tmps = [self.dataSource uploaderGetChunkUploadParams:self params:self.fileUploadParams chunkIndex:index];
    }
    NSDictionary *uploadParams = tmps ?: self.fileUploadParams;
    return uploadParams;
}

//获取上传formData
- (NSData *)getHTTPBodyDataWithParams:(NSDictionary *)params uploadData:(NSData *)uploadData {
    NSParameterAssert(uploadData != nil);
    
    NSMutableData *totlData = [NSMutableData data];
    NSArray *allKeys = [params allKeys];
    for (int i = 0; i < allKeys.count; i++) {
        NSString *disposition = [NSString stringWithFormat:@"%@Content-Disposition: form-data; name=\"%@\"%@", StartBoundary, allKeys[i], Wrap2];
        NSString *value = [params objectForKey:allKeys[i]];
        disposition = [disposition stringByAppendingString:[NSString stringWithFormat:@"%@", value]];
        disposition = [disposition stringByAppendingString:Wrap1];
        [totlData appendData:[disposition dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    NSString *body = [NSString stringWithFormat:@"%@Content-Disposition: form-data; name=\"picture\"; filename=\"%@\";Content-Type:video/mpeg4%@", StartBoundary, @"file", Wrap2];
    [totlData appendData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [totlData appendData:uploadData];
    [totlData appendData:[Wrap1 dataUsingEncoding:NSUTF8StringEncoding]];
    [totlData appendData:[EndBody dataUsingEncoding:NSUTF8StringEncoding]];
    
    return totlData;
}

//获取待上传文件的信息
- (WGLUploadFileInfo *)getUploadFileInfo:(WGLFileStreamOperation *)fileOperation {
    WGLUploadFileInfo *info = [[WGLUploadFileInfo alloc] init];
    if (fileOperation) {
        info.filePath = fileOperation.filePath;
        info.fileName = fileOperation.fileName;
        info.fileSize = fileOperation.fileSize;
        info.fileMD5String = fileOperation.fileMD5String;
        info.bizId = fileOperation.bizId;
        info.fragmentCount = fileOperation.streamFragments.count;
        info.uploadedSize = fileOperation.uploadedSize;
        info.uploadProgress = fileOperation.uploadProgress;
    }
    return info;
}

@end
