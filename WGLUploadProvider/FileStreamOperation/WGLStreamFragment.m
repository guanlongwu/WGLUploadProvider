//
//  WGLStreamFragment.m
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/24.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import "WGLStreamFragment.h"

@implementation WGLStreamFragment

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.fragmentId forKey:@"fragmentId"];
    [aCoder encodeObject:@(self.fragmentSize) forKey:@"fragmentSize"];
    [aCoder encodeObject:@(self.fragmentOffset) forKey:@"fragmentOffset"];
    [aCoder encodeObject:@(self.isUploadSuccess) forKey:@"isUploadSuccess"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        self.fragmentId = [aDecoder decodeObjectForKey:@"fragmentId"];
        self.fragmentSize = [[aDecoder decodeObjectForKey:@"fragmentSize"] unsignedIntegerValue];
        self.fragmentOffset = [[aDecoder decodeObjectForKey:@"fragmentOffset"] unsignedIntegerValue];
        self.isUploadSuccess = [[aDecoder decodeObjectForKey:@"isUploadSuccess"] boolValue];
    }
    return self;
}

@end
