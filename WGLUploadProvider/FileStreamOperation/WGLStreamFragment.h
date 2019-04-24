//
//  WGLStreamFragment.h
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/24.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WGLStreamFragment : NSObject <NSCoding>

@property (nonatomic, copy) NSString *fragmentId; //片的唯一标识
@property (nonatomic, assign) NSUInteger fragmentSize; //片的大小
@property (nonatomic, assign) NSUInteger fragmentOffset; //片的偏移量
@property (nonatomic, assign) BOOL isUploadSuccess; //是否上传成功

@end

NS_ASSUME_NONNULL_END
