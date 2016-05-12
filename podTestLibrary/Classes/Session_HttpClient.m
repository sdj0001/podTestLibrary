//
//  Session_HttpClient.m
//  NSURLSession
//
//  Created by spoon on 16/4/26.
//  Copyright © 2016年 222. All rights reserved.
//

#import "Session_HttpClient.h"
#import <Security/Security.h>

static NSString *baseURL = @"https://cashier.redlion56.com/cashier/";

static dispatch_queue_t httpClient_session_creation_queue() {
    static dispatch_queue_t my_httpClient_session_creation_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        my_httpClient_session_creation_queue = dispatch_queue_create("com.my.httpClient.session.queue.creation", DISPATCH_QUEUE_SERIAL);
    });
    return my_httpClient_session_creation_queue;
}

static dispatch_queue_t httpClient_session_processing_queue() {
    static dispatch_queue_t my_httpClient_session_processing_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        my_httpClient_session_processing_queue = dispatch_queue_create("com.my.httpClient.session.processing.queue", DISPATCH_QUEUE_CONCURRENT);
    });
    return my_httpClient_session_processing_queue;
}

static dispatch_group_t httpClient_session_completion_groupe() {
    static dispatch_group_t my_httpClient_session_completion_groupe;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        my_httpClient_session_completion_groupe = dispatch_group_create();
    });
    return my_httpClient_session_completion_groupe;
}


typedef void (^SessionHttpClientTaskCompletionHandler)(NSURLResponse *response, id responseObject, NSError *error);

@interface Session_HttpClient () <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (readwrite, nonatomic, strong) NSURLSessionConfiguration *sessionConfiguration;
@property (readwrite, nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, copy) SessionHttpClientTaskCompletionHandler completionHandler;
@property (nonatomic, strong) NSMutableData *mutableData;

@property (nonatomic, strong, nullable) dispatch_group_t completionGroup;
@property (nonatomic, strong, nullable) dispatch_queue_t completionQueue;

@property (nonatomic, strong) NSArray *trustedCertificates;

@end

@implementation Session_HttpClient

+ (instancetype)shareInstance {
    
    static Session_HttpClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[Session_HttpClient alloc] init];
    });
    
    return instance;
}

- (instancetype)init {
    
    self = [super init];
    if (!self) {
        return nil;
    }
    
    NSString * testCerPath = [[NSBundle mainBundle] pathForResource:@"HSWLROOTCAforInternalTest" ofType:@"crt"]; //证书的路径
    NSData * testCerData = [NSData dataWithContentsOfFile:testCerPath];
    SecCertificateRef certificateTest = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)(testCerData));
    
    NSString * cerPath = [[NSBundle mainBundle] pathForResource:@"HSWLROOTCA" ofType:@"crt"]; //证书的路径
    NSData * cerData = [NSData dataWithContentsOfFile:cerPath];
    SecCertificateRef certificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)(cerData));
    
    self.trustedCertificates = @[CFBridgingRelease(certificate), CFBridgingRelease(certificateTest)];
    
    self.sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    self.operationQueue = [[NSOperationQueue alloc] init];
    self.operationQueue.maxConcurrentOperationCount = 1;
    
    self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration delegate:self delegateQueue:self.operationQueue];
    
    return self;
}

#pragma mark - Public Method

//GET方法

- (void)getURL:(NSString *)url
    parameters:(id)parameters
       success:(void(^)(id response))success
       failure:(void(^)(id error))failure {
    
    NSString *encoded = [[NSString stringWithFormat:@"%@%@", baseURL, url] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self GET:encoded
   parameters:parameters
      success:^(NSURLSessionDataTask *task, id responseObject) {
        if (success) success(responseObject);
      } failure:^(NSURLSessionDataTask *task, NSError *error) {
          failure(error);
      }];
}

- (void)postURL:(NSString *)url
    parameters:(id)parameters
       success:(void(^)(id response))success
       failure:(void(^)(id error))failure {
    
    NSString *encoded = [[NSString stringWithFormat:@"%@%@", baseURL, url] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self POST:encoded
   parameters:parameters
      success:^(NSURLSessionDataTask *task, id responseObject) {
          if (success) success(responseObject);
      } failure:^(NSURLSessionDataTask *task, NSError *error) {
          failure(error);
      }];
}

#pragma mark - Privite Method

- (NSURLSessionDataTask *)GET:(NSString *)URLString
                   parameters:(id)parameters
                      success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                      failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    
    return [self dataTaskWithHTTPMethod:@"GET" URLString:URLString parameters:parameters success:success failure:failure];
}

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                   parameters:(id)parameters
                      success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                      failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    
    return [self dataTaskWithHTTPMethod:@"POST" URLString:URLString parameters:parameters success:success failure:failure];
}

- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                                       URLString:(NSString *)URLString
                                      parameters:(id)parameters
                                         success:(void (^)(NSURLSessionDataTask *, id))success
                                         failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    
    NSDictionary *params = (NSDictionary *)parameters;
    
    NSMutableURLRequest *request;
    
    if ([method isEqualToString:@"GET"]) {
        if (params && params.allKeys.count > 0) {
            NSMutableString *url = [NSMutableString stringWithString:URLString];
            [url appendFormat:@"?%@", [self buildParams:params]];
            request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        } else {
            request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
        }
        request.HTTPMethod = @"GET";
    } else if ([method isEqualToString:@"POST"]) {
        request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
        request.HTTPMethod = @"POST";
        [request addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        if (params && params.allKeys.count > 0) {
            request.HTTPBody = [[self buildParams:parameters] dataUsingEncoding:NSUTF8StringEncoding];
        }
    }

    
    NSURLSessionDataTask *task = [self dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        if (error) {
            if (failure) {
                failure(task, error);
            }
            
        } else {
            if (success) {
                success(task, responseObject);
            }
            
        }
    }];
    
    [task resume];
    
    return task;
    
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler {
    
    __block NSURLSessionDataTask *task;
    dispatch_sync(httpClient_session_creation_queue(), ^{
        task = [self.session dataTaskWithRequest:request];
    });
    self.completionHandler = completionHandler;
    if (!self.mutableData) self.mutableData = [NSMutableData data];
    return task;
}


- (NSString *)buildParams:(NSDictionary *)paramseters {
    
    __block NSMutableString *components = [NSMutableString string];
    
    if (paramseters && paramseters.allKeys.count > 0) {
        
        [paramseters.allKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL * _Nonnull stop) {
            
            if (idx == 0) {
                [components appendFormat:@"%@=%@", key, paramseters[key]];
            } else {
                [components appendFormat:@"&%@=%@", key, paramseters[key]];
            }
            
        }];
    }
    
    return components;
    
}

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error {
    if (data) {
        return [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:error];
    } else {
        return nil;
    }
}

- (void)URLSession:(NSURLSession *)session task:(nonnull NSURLSessionTask *)task didReceiveChallenge:(nonnull NSURLAuthenticationChallenge *)challenge completionHandler:(nonnull void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    
    SecTrustRef trust = challenge.protectionSpace.serverTrust;
    SecTrustResultType result;
    
    //注意：这里将之前导入的证书设置成下面验证的Trust Object的anchor certificate
    SecTrustSetAnchorCertificates(trust, (__bridge CFArrayRef)self.trustedCertificates);
    
    //2)SecTrustEvaluate会查找前面SecTrustSetAnchorCertificates设置的证书或者系统默认提供的证书，对trust进行验证
    OSStatus status = SecTrustEvaluate(trust, &result);
    
    if (status == errSecSuccess &&
        (result == kSecTrustResultProceed ||
         result == kSecTrustResultUnspecified)) {
            
            NSLog(@"success");
            NSURLCredential *cred = [NSURLCredential credentialForTrust:trust];
            completionHandler(NSURLSessionAuthChallengeUseCredential, cred);
        } else {
            NSLog(@"failure");
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        }
}

#pragma mark - NSURLSessionTaskDelegate


- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
    __block id responseObject = nil;
    
    NSData *data = nil;
    if (self.mutableData) {
        data = [self.mutableData copy];
        self.mutableData = nil;
    }
    
    if (error) {
        dispatch_group_async(self.completionGroup ?: httpClient_session_completion_groupe() , self.completionQueue ?: dispatch_get_main_queue(), ^{
            if (self.completionHandler) {
                self.completionHandler(task.response, responseObject, error);
            }
        });
    } else {
        dispatch_async(httpClient_session_processing_queue(), ^{
            NSError *serializationError = nil;
            responseObject = [self responseObjectForResponse:task.response data:data error:&serializationError];
            
            dispatch_group_async(self.completionGroup ?: httpClient_session_completion_groupe() , self.completionQueue ?: dispatch_get_main_queue(), ^{
                if (self.completionHandler) {
                    self.completionHandler(task.response, responseObject, serializationError);
                }
            });
        });
    }
}

#pragma mark - NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.mutableData appendData:data];
}




@end
