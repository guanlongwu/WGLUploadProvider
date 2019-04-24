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

@property (nonatomic, assign) BOOL isReadOperation; //YES：读文件；NO：写文件
@property (nonatomic, strong) NSFileHandle *readFileHandle; //读文件句柄
@property (nonatomic, strong) NSFileHandle *writeFileHandle; //写文件句柄
@property (nonatomic, copy) NSString *filePath; //文件路径
@property (nonatomic, copy) NSString *fileName; //文件名
@property (nonatomic, assign) NSUInteger fileSize; //文件大小
@property (nonatomic, copy) NSString *fileMD5String; //文件md5编码名称
@property (nonatomic, copy) NSString *bizId;
@property (nonatomic, assign) double uploadProgress;  //上传进度
@property (nonatomic, assign) NSInteger uploadedSize; //已上传文件大小
@property (nonatomic, assign) WGLUploadStatus uploadStatus;//文件上传状态
@property (nonatomic, strong) NSArray <WGLStreamFragment *> *streamFragments; //文件分片数组

//初始化
- (instancetype)initWithFilePath:(NSString *)path isReadOperation:(BOOL)isReadOperation;

//读取对应分片data
- (NSData *)readDataOfFragment:(WGLStreamFragment *)fragment;

@end

NS_ASSUME_NONNULL_END
