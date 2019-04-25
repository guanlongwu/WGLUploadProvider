//
//  WGLUploadFileInfo.h
//  WGLKitDemo
//
//  Created by wugl on 2019/4/25.
//  Copyright © 2019 huya. All rights reserved.
//
/**
 待上传文件的信息
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WGLUploadFileInfo : NSObject

@property (nonatomic, copy) NSString *filePath; //文件路径
@property (nonatomic, copy) NSString *fileName; //文件名
@property (nonatomic, assign) NSUInteger fileSize; //文件大小
@property (nonatomic, copy) NSString *fileMD5String; //文件md5编码名称
@property (nonatomic, copy) NSString *bizId;
@property (nonatomic, assign) NSInteger fragmentCount; //文件分片数
@property (nonatomic, assign) double uploadProgress;  //上传进度
@property (nonatomic, assign) NSInteger uploadedSize; //已上传文件大小

@end

NS_ASSUME_NONNULL_END
