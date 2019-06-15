//
//  WGLUploadUtils.h
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/24.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WGLFileStreamOperation.h"

#define KWGLUploadPlist     @"uploadPlist/upload.plist"
#define WGLUploadPlistPath  [[WGLUploadUtils cachesDir] stringByAppendingPathComponent:KWGLUploadPlist]

NS_ASSUME_NONNULL_BEGIN

@interface WGLUploadUtils : NSObject

//生成一个唯一ID
+ (NSString *)uniqueID;

//根据文件路径，生成一个文件MD5值
+(NSString*)fileMD5WithPath:(NSString*)path;

#pragma mark - 缓存

//归档“添加”
+ (BOOL)archivedDataByAddFileStream:(WGLFileStreamOperation *)fileStream;

//归档“移除”
+ (BOOL)archivedDataByRemoveFileStream:(WGLFileStreamOperation *)fileStream;

//解档
+ (NSMutableDictionary <NSString *, WGLFileStreamOperation *>*)unArchivedFilePlist;

//解档
+ (WGLFileStreamOperation *)unArchivedFileStreamForFileName:(NSString *)fileName;

//缓存列表
+ (NSMutableDictionary *)fileStreamDic;


@end

NS_ASSUME_NONNULL_END
