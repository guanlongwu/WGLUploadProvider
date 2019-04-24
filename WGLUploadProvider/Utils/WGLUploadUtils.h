//
//  WGLUploadUtils.h
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/24.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WGLUploadUtils : NSObject

//生成一个唯一ID
+ (NSString *)uniqueID;

//根据文件路径，生成一个文件MD5值
+(NSString*)fileMD5WithPath:(NSString*)path;

@end

NS_ASSUME_NONNULL_END
