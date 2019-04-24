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



#pragma mark - WGLUploaderDelegate

- (NSURLRequest *)uploaderGetUploadURLRequest:(WGLUploader *)uploader {
    NSURLRequest *req = nil;
    if ([self.dataSource respondsToSelector:@selector(uploaderGetUploadURLRequest:)]) {
        req = [self.dataSource uploaderGetUploadURLRequest:self];
    }
    return req;
}

- (void)uploaderGetParamsBeforeUpload:(WGLUploader *)uploader fileOperation:(WGLFileStreamOperation *)fileOperation completion:(WGLGetFileParamsBeforeUploadCompletion)completion {
    
}

- (NSDictionary *)uploaderGetUploadParams:(WGLUploader *)uploader streamFragments:(NSArray <WGLStreamFragment*> *)streamFragments segmentIndex:(NSInteger)segmentIndex params:(NSDictionary *)params {
    NSDictionary *dic = nil;
    
    return dic;
}

//上传中
- (void)uploaderUploading:(WGLUploader *)uploader fileOperation:(WGLFileStreamOperation *)fileOperation {
    
}

//上传成功
- (void)uploaderDidFinish:(WGLUploader *)uploader fileOperation:(WGLFileStreamOperation *)fileOperation {
    
}

//上传失败
- (void)uploaderDidFailure:(WGLUploader *)uploader fileOperation:(WGLFileStreamOperation *)fileOperation error:(NSError *)error {
    
}

//上传取消
- (void)uploaderDidCancel:(WGLUploader *)uploader fileOperation:(WGLFileStreamOperation *)fileOperation {
    
}


@end
