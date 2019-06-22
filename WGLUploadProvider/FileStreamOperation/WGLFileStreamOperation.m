//
//  WGLFileStreamOperation.m
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/24.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import "WGLFileStreamOperation.h"
#import "WGLUploadUtils.h"

#define WGLStreamFragmentMaxSize (1024 * 512) // 每个分片最大512KB

@interface WGLFileStreamOperation ()
@property (nonatomic, assign) BOOL isReadOperation; //YES：读文件；NO：写文件
@property (nonatomic, strong) NSFileHandle *readFileHandle; //读文件句柄
@property (nonatomic, strong) NSFileHandle *writeFileHandle; //写文件句柄

@property (nonatomic, copy) NSString *fileName; //文件名
@property (nonatomic, assign) NSUInteger fileSize; //文件大小
@property (nonatomic, copy) NSString *fileMD5String; //文件md5编码名称
@property (nonatomic, copy) NSString *bizId;
@property (nonatomic, assign) double uploadProgress;  //上传进度
@property (nonatomic, assign) NSInteger uploadedSize; //已上传文件大小
@property (nonatomic, strong) NSArray <WGLStreamFragment *> *streamFragments; //文件分片数组
@end

@implementation WGLFileStreamOperation

#pragma mark - init

- (instancetype)initWithFilePath:(NSString *)path isReadOperation:(BOOL)isReadOperation {
    if (self = [super init]) {
        _isReadOperation = isReadOperation;
        _filePath = path;
        
        if (_isReadOperation) {
            //读操作：打开一个已存在的文件
            
            if (NO == [self getFileInfoWithPath:path]) {
                return nil;
            }
            self.readFileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
            
            //进行切片处理
            [self cutFileForFragments];
        }
        else {
            //写操作：如果文件不存在，会创建的新的空文件
            
            NSFileManager *fileMgr = [NSFileManager defaultManager];
            if (![fileMgr fileExistsAtPath:path]) {
                [fileMgr createFileAtPath:path contents:nil attributes:nil];
            }
            if (NO == [self getFileInfoWithPath:path]) {
                return nil;
            }
            self.writeFileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
        }
    }
    return self;
}

#pragma mark - 获取文件信息

//根据文件路径，获取文件信息
- (BOOL)getFileInfoWithPath:(NSString *)path {
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"文件不存在：%@", path);
        return NO;
    }
    self.filePath = path;
    self.bizId = [[NSUUID UUID] UUIDString];
    self.fileMD5String = [WGLUploadUtils fileMD5WithPath:path];
    self.fileName = [path lastPathComponent];
    self.uploadStatus = WGLUploadStatusWaiting;
    
    NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    self.fileSize = attr.fileSize;
    
    self.uploadedSize = 0;
    self.uploadProgress = 0.00;
    
    return YES;
}

//文件信息
+ (WGLFileStreamOperation *)fileInfoWithFilePath:(NSString *)filePath {
    WGLFileStreamOperation *operation = [WGLFileStreamOperation new];
    [operation getFileInfoWithPath:filePath];
    return operation;
}

#pragma mark - 读操作

//切分文件片段
- (void)cutFileForFragments {
    //每片512KB
    NSUInteger offset = WGLStreamFragmentMaxSize;
    //文件将要切分的片数
    NSUInteger chunks =
    (self.fileSize % offset == 0) ? (self.fileSize / offset) : ((self.fileSize / offset) + 1);
    
    NSMutableArray <WGLStreamFragment *> *fragments = [[NSMutableArray alloc] initWithCapacity:0];
    for (NSUInteger i = 0; i < chunks; i ++) {
        WGLStreamFragment *fragment = [[WGLStreamFragment alloc] init];
        fragment.isUploadSuccess = NO;
        fragment.fragmentId = [WGLUploadUtils uniqueID];
        fragment.fragmentOffset = i * offset;
        if (i != chunks - 1) {
            fragment.fragmentSize = offset;
        }
        else {
            //计算最后一片的大小
            fragment.fragmentSize = self.fileSize - fragment.fragmentOffset;
        }
        
        [fragments addObject:fragment];
    }
    self.streamFragments = fragments;
}

//读取对应分片data
- (NSData *)readDataOfFragment:(WGLStreamFragment *)fragment {
    if (!_readFileHandle) {
        self.readFileHandle = [NSFileHandle fileHandleForReadingAtPath:self.filePath];
    }
    if (fragment) {
        [self.readFileHandle seekToFileOffset:fragment.fragmentOffset];
        return [self.readFileHandle readDataOfLength:fragment.fragmentSize];
    }
    [self closeFile];
    return nil;
}

//关闭文件
- (void)closeFile {
    if (self.isReadOperation) {
        [self.readFileHandle closeFile];
    }
    else {
        [self.writeFileHandle closeFile];
    }
}

#pragma mark - setter

//上传状态
- (void)setUploadStatus:(WGLUploadStatus)uploadStatus {
    _uploadStatus = uploadStatus;
    
    //更新上传进度和已上传文件大小
    NSInteger count = self.streamFragments.count;
    for (int idx = 0; idx < count; idx ++) {
        WGLStreamFragment *obj = self.streamFragments[idx];
        if (idx == count - 1) {
            self.uploadProgress = (idx + 1.0) / count;
            self.uploadedSize = self.fileSize;
            break;
        }
        if (NO == obj.isUploadSuccess) {
            self.uploadProgress = (idx + 1.0) / count;
            self.uploadedSize = WGLStreamFragmentMaxSize * (idx + 1);
            break;
        }
    }
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.fileName forKey:@"fileName"];
    [aCoder encodeObject:@(self.fileSize) forKey:@"fileSize"];
    [aCoder encodeObject:@(self.uploadStatus) forKey:@"uploadStatus"];
    [aCoder encodeObject:self.filePath forKey:@"filePath"];
    [aCoder encodeObject:self.fileMD5String forKey:@"fileMD5String"];
    [aCoder encodeObject:self.streamFragments forKey:@"streamFragments"];
    [aCoder encodeObject:self.bizId forKey:@"bizId"];
    [aCoder encodeObject:@(self.uploadedSize) forKey:@"uploadedSize"];
    [aCoder encodeObject:@(self.uploadProgress) forKey:@"uploadProgress"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        self.fileName = [aDecoder decodeObjectForKey:@"fileName"];
        self.uploadStatus = [[aDecoder decodeObjectForKey:@"uploadStatus"] integerValue];
        self.fileSize = [[aDecoder decodeObjectForKey:@"fileSize"] unsignedIntegerValue];
        self.filePath = [aDecoder decodeObjectForKey:@"filePath"];
        self.fileMD5String = [aDecoder decodeObjectForKey:@"fileMD5String"];
        self.streamFragments = [aDecoder decodeObjectForKey:@"streamFragments"];
        self.bizId = [aDecoder decodeObjectForKey:@"bizId"];
        self.uploadProgress = [[aDecoder decodeObjectForKey:@"uploadProgress"] doubleValue];
        self.uploadedSize = [[aDecoder decodeObjectForKey:@"uploadedSize"] unsignedIntegerValue];
    }
    return self;
}

@end
