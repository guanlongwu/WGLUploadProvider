//
//  WGLUploader.m
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/24.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import "WGLUploader.h"
#import "WGLUploadUtils.h"

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

#pragma mark - 上传

//开始上传文件
- (void)startUpload {
    self.isUserSuspended = NO;
    
    if (self.fileUploadParams) {
        //已经获取上传参数，则开始上传
        
        //回调：上传开始
        WGLUploadFileInfo *fileInfo = [self getUploadFileInfo:self.fileOperation];
        if ([self.delegate respondsToSelector:@selector(uploaderDidStart:fileInfo:)]) {
            [self.delegate uploaderDidStart:self fileInfo:fileInfo];
        }
        
        [self uploadFileWithIndex:0 streamFragments:self.fileOperation.streamFragments];
    }
    else {
        //上传之前先获取参数
        
        __weak typeof(self) weakSelf = self;
        WGLGetFileParamsBeforeUploadHandler handler = ^(NSDictionary *params) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            //获取到参数
            strongSelf.fileUploadParams = [NSMutableDictionary dictionaryWithDictionary:params];
            //执行上传
            [strongSelf startUpload];
        };
        
        //获取参数的操作由代理实现
        WGLUploadFileInfo *fileInfo = [self getUploadFileInfo:self.fileOperation];
        if ([self.dataSource respondsToSelector:@selector(uploaderGetParamsBeforeUpload:fileInfo:handler:)]) {
            [self.dataSource uploaderGetParamsBeforeUpload:self fileInfo:fileInfo handler:handler];
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
        [self updateFileUploadInfoIfSuccess];
        
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
                [strongSelf updateFileUploadInfoIfSuccess];
                
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
        
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
            completionHandler(nil, nil, error);
        }
        return;
    }
    NSMutableURLRequest *req = [self getUploadRequest];
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
    [self updateFileUploadPlistIfCancel];
    
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

- (void)updateFileUploadInfoIfSuccess {
    BOOL result = [WGLUploadUtils archivedDataByAddFileStream:self.fileOperation];
    if (NO == result) {
        NSLog(@"归档失败");
    }
}

- (void)updateFileUploadPlistIfCancel {
    BOOL result = [WGLUploadUtils archivedDataByRemoveFileStream:self.fileOperation];
    if (NO == result) {
        NSLog(@"归档失败");
    }
}

#pragma mark - private

//获取上传request
- (NSMutableURLRequest *)getUploadRequest {
    NSMutableURLRequest *req = nil;
    if ([self.dataSource respondsToSelector:@selector(uploaderGetUploadURLRequest:)]) {
        req = [self.dataSource uploaderGetUploadURLRequest:self];
    }
    if (![req valueForHTTPHeaderField:@"Content-Type"]) {
        [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    }
    return req;
}

//获取分片上传的params
- (NSDictionary *)getChunkFileUploadParams:(NSInteger)index {
    NSDictionary *tmps = nil;
    if ([self.dataSource respondsToSelector:@selector(uploaderGetChunkUploadParams:params:chunkIndex:)]) {
        tmps = [self.dataSource uploaderGetChunkUploadParams:self params:self.fileUploadParams chunkIndex:index];
    }
    NSDictionary *uploadParams = tmps;
    if (!uploadParams || uploadParams.allKeys.count == 0) {
        uploadParams = self.fileUploadParams;
    }
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
    
    NSString *name = kDefaultAppendDataName;
    NSString *fileName = kDefaultAppendDataFileName;
    NSString *mimeType = kDefaultAppendDataMimeType;
    [self getAppendDataPartParamsForName:&name fileName:&fileName mimeType:&mimeType];
    
    NSString *body = [NSString stringWithFormat:@"%@Content-Disposition: form-data; name=\"%@\"; filename=\"%@\";Content-Type:%@%@", StartBoundary, name, fileName, mimeType, Wrap2];
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
        info.uploadStatus = fileOperation.uploadStatus;
    }
    return info;
}

//获取请求body的part参数：name、fileName、mimeType
- (void)getAppendDataPartParamsForName:(NSString **)name fileName:(NSString **)fileName mimeType:(NSString **)mimeType {
    __block NSString *_name = nil;
    __block NSString *_fileName = nil;
    __block NSString *_mimeType = nil;
    
    if ([self.dataSource respondsToSelector:@selector(uploaderGetParamsForAppendPartData:handler:)]) {
        [self.dataSource uploaderGetParamsForAppendPartData:self handler:^(NSString * _Nullable name, NSString * _Nullable fileName, NSString * _Nullable mimeType) {
            _name = name;
            _fileName = fileName;
            _mimeType = mimeType;
        }];
    }
    
    *name = _name.length > 0 ? _name : kDefaultAppendDataName;
    *fileName = _fileName.length > 0 ? _fileName : kDefaultAppendDataFileName;
    *mimeType = _mimeType.length > 0 ? _mimeType : kDefaultAppendDataMimeType;
    
}

@end
