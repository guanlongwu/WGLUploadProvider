//
//  WGLFileStreamOperation.h
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/24.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WGLStreamFragment.h"
#import "WGLUploadHead.h"

NS_ASSUME_NONNULL_BEGIN

/**
 文件流操作类
 */
@interface WGLFileStreamOperation : NSObject <NSCoding>

@property (nonatomic, copy) NSString *filePath; //文件路径
@property (nonatomic, assign) WGLUploadStatus uploadStatus;//文件上传状态

@property (nonatomic, copy, readonly) NSString *fileName; //文件名
@property (nonatomic, assign, readonly) NSUInteger fileSize; //文件大小
@property (nonatomic, copy, readonly) NSString *fileMD5String; //文件md5编码名称
@property (nonatomic, copy, readonly) NSString *bizId;
@property (nonatomic, assign, readonly) double uploadProgress;  //上传进度
@property (nonatomic, assign, readonly) NSInteger uploadedSize; //已上传文件大小
@property (nonatomic, strong, readonly) NSArray <WGLStreamFragment *> *streamFragments; //文件分片数组

//初始化
- (instancetype)initWithFilePath:(NSString *)path isReadOperation:(BOOL)isReadOperation;

//读取对应分片data
- (NSData *)readDataOfFragment:(WGLStreamFragment *)fragment;

@end

NS_ASSUME_NONNULL_END
