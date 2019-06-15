//
//  WGLUploadUtils.m
//  WGLUploadProvider
//
//  Created by wugl on 2019/4/24.
//  Copyright © 2019 WGLKit. All rights reserved.
//

#import "WGLUploadUtils.h"
#import <CommonCrypto/CommonDigest.h>

#define FileHashDefaultChunkSizeForReadingData (1024 * 8)

@implementation WGLUploadUtils

//生成一个唯一ID
+ (NSString *)uniqueID {
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef cfstring = CFUUIDCreateString(kCFAllocatorDefault, uuid);
    const char *cStr = CFStringGetCStringPtr(cfstring,CFStringGetFastestEncoding(cfstring));
    unsigned char result[16];
    CC_MD5( cStr, (unsigned int)strlen(cStr), result );
    CFRelease(uuid);
    CFRelease(cfstring);
    
    return [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%08lx",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15],
            (unsigned long)(arc4random() % NSUIntegerMax)];
}

//根据文件路径，生成一个文件MD5值
+(NSString*)fileMD5WithPath:(NSString*)path {
    return (__bridge_transfer NSString *)FileMD5HashCreateWithPath((__bridge CFStringRef)path, FileHashDefaultChunkSizeForReadingData);
}

CFStringRef FileMD5HashCreateWithPath(CFStringRef filePath,size_t chunkSizeForReadingData) {
    // Declare needed variables
    CFStringRef result = NULL;
    CFReadStreamRef readStream = NULL;
    // Get the file URL
    CFURLRef fileURL =
    CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                  (CFStringRef)filePath,
                                  kCFURLPOSIXPathStyle,
                                  (Boolean)false);
    if (!fileURL) goto done;
    // Create and open the read stream
    readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault,
                                            (CFURLRef)fileURL);
    if (!readStream) goto done;
    bool didSucceed = (bool)CFReadStreamOpen(readStream);
    if (!didSucceed) goto done;
    // Initialize the hash object
    CC_MD5_CTX hashObject;
    CC_MD5_Init(&hashObject);
    // Make sure chunkSizeForReadingData is valid
    if (!chunkSizeForReadingData) {
        chunkSizeForReadingData = FileHashDefaultChunkSizeForReadingData;
    }
    // Feed the data to the hash object
    bool hasMoreData = true;
    while (hasMoreData) {
        uint8_t buffer[chunkSizeForReadingData];
        CFIndex readBytesCount = CFReadStreamRead(readStream,(UInt8 *)buffer,(CFIndex)sizeof(buffer));
        if (readBytesCount == -1) break;
        if (readBytesCount == 0) {
            hasMoreData = false;
            continue;
        }
        CC_MD5_Update(&hashObject,(const void *)buffer,(CC_LONG)readBytesCount);
    }
    // Check if the read operation succeeded
    didSucceed = !hasMoreData;
    // Compute the hash digest
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &hashObject);
    // Abort if the read operation failed
    if (!didSucceed) goto done;
    // Compute the string result
    char hash[2 * sizeof(digest) + 1];
    for (size_t i = 0; i < sizeof(digest); ++i) {
        snprintf(hash + (2 * i), 3, "%02x", (int)(digest[i]));
    }
    result = CFStringCreateWithCString(kCFAllocatorDefault,(const char *)hash,kCFStringEncodingUTF8);
    
done:
    if (readStream) {
        CFReadStreamClose(readStream);
        CFRelease(readStream);
    }
    if (fileURL) {
        CFRelease(fileURL);
    }
    return result;
}

#pragma mark - 缓存

//归档“添加”
+ (BOOL)archivedDataByAddFileStream:(WGLFileStreamOperation *)fileStream {
    NSMutableDictionary *fileStreamDic = [WGLUploadUtils fileStreamDic];
    [fileStreamDic setObject:fileStream forKey:fileStream.fileName];
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:fileStreamDic];
    
    [WGLUploadUtils createFilePlistPathIfNeed];
    BOOL finish = [data writeToFile:WGLUploadPlistPath atomically:YES];
    return finish;
}

//归档“移除”
+ (BOOL)archivedDataByRemoveFileStream:(WGLFileStreamOperation *)fileStream {
    NSMutableDictionary *fileStreamDic = [WGLUploadUtils fileStreamDic];
    if (nil == fileStreamDic[fileStream.fileName]) {
        return NO;
    }
    [fileStreamDic removeObjectForKey:fileStream.fileName];
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:fileStreamDic];
    
    [WGLUploadUtils createFilePlistPathIfNeed];
    BOOL finish = [data writeToFile:WGLUploadPlistPath atomically:YES];
    return finish;
}

//解档
+ (NSMutableDictionary <NSString *, WGLFileStreamOperation *>*)unArchivedFilePlist {
    [WGLUploadUtils createFilePlistPathIfNeed];
    NSMutableDictionary *dic = [NSKeyedUnarchiver unarchiveObjectWithFile:WGLUploadPlistPath];
    return dic;
}

//解档
+ (WGLFileStreamOperation *)unArchivedFileStreamForFileName:(NSString *)fileName {
    NSMutableDictionary *fileStreamDic = [WGLUploadUtils fileStreamDic];
    WGLFileStreamOperation *fileStream = [fileStreamDic objectForKey:fileName];
    return fileStream;
}

//缓存列表
+ (NSMutableDictionary *)fileStreamDic {
    static NSMutableDictionary *fileStreamDic = nil;
    fileStreamDic = [WGLUploadUtils unArchivedFilePlist];
    if (!fileStreamDic) {
        fileStreamDic = [[NSMutableDictionary alloc] init];
    }
    return fileStreamDic;
}

+ (void)createFilePlistPathIfNeed {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (NO == [fileManager fileExistsAtPath:WGLUploadPlistPath]) {
        [WGLUploadUtils createFileAtPath:WGLUploadPlistPath];
    }
}

+ (NSString *)cachesDir {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
}

+ (BOOL)createFileAtPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // 如果文件夹路径不存在，那么先创建文件夹
    NSString *directoryPath = [path stringByDeletingLastPathComponent];
    if (NO == [fileManager fileExistsAtPath:directoryPath]) {
        // 创建文件夹
        BOOL isSuccess = [fileManager createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
        if (NO == isSuccess) {
            return NO;
        }
    }
    // 如果文件存在，并不想覆盖，那么直接返回YES。
    if (YES == [fileManager fileExistsAtPath:path]) {
        return YES;
    }
    // 创建文件
    BOOL isSuccess = [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    return isSuccess;
}

@end
