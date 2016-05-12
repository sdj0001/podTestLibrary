//
//  Session_HttpClient.h
//  NSURLSession
//
//  Created by spoon on 16/4/26.
//  Copyright © 2016年 222. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Session_HttpClient : NSObject

+ (instancetype)shareInstance;

- (void)getURL:(NSString *)url
    parameters:(id)parameters
       success:(void(^)(id response))success
       failure:(void(^)(id error))failure;

- (void)postURL:(NSString *)url
     parameters:(id)parameters
        success:(void(^)(id response))success
        failure:(void(^)(id error))failure;

@end
