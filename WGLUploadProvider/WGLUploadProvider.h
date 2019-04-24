//
//  WGLUploadProvider.h
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/23.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WGLUploadHead.h"
@protocol WGLUploadProviderDataSource;
@protocol WGLUploadProviderDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface WGLUploadProvider : NSObject
@property (nonatomic, weak) id <WGLUploadProviderDataSource> dataSource;
@property (nonatomic, weak) id <WGLUploadProviderDelegate> delegate;

+ (instancetype)sharedProvider;

/**
 最大支持上传数
 默认-1，表示不进行限制
 */
@property (nonatomic, assign) NSInteger maxUploadCount;

/**
 最大并发上传数
 默认2
 */
@property (nonatomic, assign) NSInteger maxConcurrentUploadCount;

/**
 上传优先级
 默认先进先出
 */
@property (nonatomic, assign) WGLUploadExeOrder executeOrder;


@end


@protocol WGLUploadProviderDataSource <NSObject>

/**
 获取文件上传的NSURLRequest对象
 
 @param ulProvider WGLUploadProvider
 @return 上传的NSURLRequest对象
 */
- (NSURLRequest *)uploaderGetUploadURLRequest:(WGLUploadProvider *)ulProvider;


@end


@protocol WGLUploadProviderDelegate <NSObject>



@end

NS_ASSUME_NONNULL_END
