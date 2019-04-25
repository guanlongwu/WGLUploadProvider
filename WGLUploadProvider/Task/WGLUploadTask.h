//
//  WGLUploadTask.h
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/24.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WGLUploadHead.h"

NS_ASSUME_NONNULL_BEGIN

@interface WGLUploadTask : NSObject

@property (nonatomic, copy) NSString *filePath; //文件路径
@property (nonatomic, assign) WGLUploadStatus uploadStatus;//文件上传状态

@end

NS_ASSUME_NONNULL_END
