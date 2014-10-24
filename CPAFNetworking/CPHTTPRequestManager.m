//
//  CPHTTPRequestManager.m
//  B2A
//
//  Created by Bob on 9/17/14.
//  Copyright (c) 2014 chinapnr. All rights reserved.
//

#import "CPHTTPRequestManager.h"
//#import "Helper.h"

typedef void (^AFRequestSuccess)(AFHTTPRequestOperation *operation, id responseObject);
typedef void (^AFRequestFailure)(AFHTTPRequestOperation *operation, NSError *error);

static NSString * const kAFCharactersToBeEscapedInQueryString = @":/?&=;+!@#$()',*";

static NSString * AFPercentEscapedQueryStringKeyFromStringWithEncoding(NSString *string, NSStringEncoding encoding) {
    static NSString * const kAFCharactersToLeaveUnescapedInQueryStringPairKey = @"[].";
    
	return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, (__bridge CFStringRef)kAFCharactersToLeaveUnescapedInQueryStringPairKey, (__bridge CFStringRef)kAFCharactersToBeEscapedInQueryString, CFStringConvertNSStringEncodingToEncoding(encoding));
}

static NSString * AFPercentEscapedQueryStringValueFromStringWithEncoding(NSString *string, NSStringEncoding encoding) {
	return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, NULL, (__bridge CFStringRef)kAFCharactersToBeEscapedInQueryString, CFStringConvertNSStringEncodingToEncoding(encoding));
}

static NSString * CPQueryStringPairsFromKeyAndValue(NSString *key, id value, BOOL escape){
    NSMutableString *queryString = [[NSMutableString alloc] initWithString:@""];
    
    if ([value isKindOfClass:[NSDictionary class]]) {
        
        key ? [queryString appendFormat:@"\"%@\":",
               escape ? AFPercentEscapedQueryStringKeyFromStringWithEncoding(key, NSUTF8StringEncoding):key] : nil;
        
        NSDictionary *dict = value;
        [queryString appendFormat:@"{"];
        
        NSArray *allKeys = [dict allKeys];
        for (int i=0; i<allKeys.count; i++) {
            id k = [allKeys objectAtIndex:i];
            id v = [dict valueForKey:k];
            [queryString appendFormat:@"%@%@", CPQueryStringPairsFromKeyAndValue(k, v, escape), (i<(allKeys.count-1))?@",":@""];
        }
        [queryString appendFormat:@"}"];
    }
    
    else if ([value isKindOfClass:[NSArray class]]){
        
        key ? [queryString appendFormat:@"\"%@\":", escape ? AFPercentEscapedQueryStringKeyFromStringWithEncoding(key, NSUTF8StringEncoding):key] : nil;
        
        NSArray *array = value;
        [queryString appendFormat:@"["];
        for (int i=0; i<array.count; i++) {
            id v = [array objectAtIndex:i];
            [queryString appendFormat:@"%@%@", CPQueryStringPairsFromKeyAndValue(nil, v, escape), (i<(array.count-1))?@",":@""];
        }
        [queryString appendFormat:@"]"];
    }else{
        if (key) {
            NSString *formatString = @"\"%@\":\"%@\"";
            if ([value isKindOfClass:[NSNumber class]]) {
                formatString = @"\"%@\":%@";
            }
            [queryString appendFormat:formatString,
             escape?AFPercentEscapedQueryStringKeyFromStringWithEncoding(key, NSUTF8StringEncoding):key,
             escape?AFPercentEscapedQueryStringValueFromStringWithEncoding(value, NSUTF8StringEncoding):value];
        }else{
            [queryString appendFormat:@"\"%@\"",
             escape?AFPercentEscapedQueryStringValueFromStringWithEncoding(value, NSUTF8StringEncoding):value];
        }
    }
    
    return queryString;
}


BOOL NotNil(id dict, NSString *k){
    if (dict!=nil && [dict isKindOfClass:[NSDictionary class]] &&
                     [dict objectForKey:k]!=nil && [dict objectForKey:k]!=[NSNull null]) {
        return YES;
    }
    return NO;
}

BOOL NotNilAndEqualsValue(id dict, NSString *k, NSString *value){
    if (NotNil(dict, k) && [[[dict valueForKey:k] description] isEqualToString:value]) {
        return YES;
    }
    return NO;
}

#define HTTP_REQ_DEFAULT_TIMEOUT_INTERVAL 60

@implementation CPHTTPRequestManager

+(instancetype)sharedInstance:(NSString *)HOST_URL{
    static CPHTTPRequestManager *sInstance;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sInstance = [[self alloc] initWithBaseURL:[NSURL URLWithString:HOST_URL]];
    });
    
    sInstance.requestSerializer.timeoutInterval = HTTP_REQ_DEFAULT_TIMEOUT_INTERVAL;
    
    return sInstance;
}

+(NSString *)respCodeDesc:(NSString *)respCode{
    static NSDictionary *dict = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = @{@"11" : @"用户名或密码错误",
                 @"12" : @"缺少session_id",
                 @"13" : @"session无效",
                 @"20" : @"缺少必要参数",
                 @"21" : @"参数错误",
                 @"91" : @"传入参数JSON格式错误",
                 @"97" : @"数据库异常",
                 @"99" : @"系统错误",
                 @"41" : @"手机号或发送内容为空",
                 @"42" : @"手机号格式错误",
                 @"43" : @"系统异常",
                 @"44" : @"手机号或验证码为空",
                 @"45" : @"验证码错误"};
    });
    
    if (NotNil(dict, respCode)) {
        return [dict objectForKey:respCode];
    }
    return @"";
}

-(instancetype)initWithBaseURL:(NSURL *)url{
    self = [super initWithBaseURL:url];
    
    self.responseSerializer.acceptableContentTypes = [self.responseSerializer.acceptableContentTypes setByAddingObject:@"text/html"];
    
    self.querySerializationBlock = ^NSString *(NSURLRequest *request, NSDictionary *parameters, NSError *__autoreleasing *error){
        NSString *queryString;
        NSSet *HTTPMethodsEncodingParametersInURI = [NSSet setWithObjects:@"GET", @"HEAD", @"DELETE", nil];
        if ([HTTPMethodsEncodingParametersInURI containsObject:[[request HTTPMethod] uppercaseString]]) {
            queryString = [NSString stringWithFormat:@"url_string=%@", CPQueryStringPairsFromKeyAndValue(nil, parameters, YES)];
            
            //do {} encoding
            
        }else{
            queryString = [NSString stringWithFormat:@"url_string=%@", CPQueryStringPairsFromKeyAndValue(nil, parameters, NO)];
        }
        
        return queryString;
    };
    
    [self.requestSerializer setQueryStringSerializationWithBlock:self.querySerializationBlock];
    
    return self;
}

-(AFRequestSuccess) extendAFHTTPRequestSuccess:(void (^)(AFHTTPRequestOperation *, id))success
                                    reqFailure:(void (^)(AFHTTPRequestOperation *, NSError *))failure{
    
    AFRequestSuccess reqSuccess = ^(AFHTTPRequestOperation *operation, id responseObject){
        NSDictionary *dict = responseObject;
        
        NSLog(@"%@", dict);
        
        if (NotNilAndEqualsValue(dict, RESP_CODE, @"00")) {
            if (NotNil(dict, @"session_id")) {
                self.sessionId = [dict objectForKey:@"session_id"];

                NSString *sessionValue = [NSString stringWithFormat:@"PHPSESSID=%@", self.sessionId];
                [self.requestSerializer setValue:sessionValue forHTTPHeaderField:@"Cookie"];
                
            }
            
            if (success) {
                success(operation, responseObject);
            }
            return ;
        }
        //session invalid
        else if (NotNilAndEqualsValue(dict, RESP_CODE, @"13")){
            
        }
        else {
            NSString *respMsg = NotNil(dict, @"resp_desc")? [dict objectForKey:@"resp_desc"] : [[self class] respCodeDesc:[dict objectForKey:RESP_CODE]];
            
            NSDictionary *usrInfo = @{NOTIFICATION_MESSAGE:respMsg};
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_UI_AUTO_PROMPT
                                                                object:nil
                                                              userInfo:usrInfo];
        }
        
        failure(operation, responseObject);
    };
     
    return reqSuccess;
}

-(AFRequestFailure) extendAFHTTPRequestFailure:(void (^)(AFHTTPRequestOperation *, NSError *))failure{
    
    AFRequestFailure reqFailure = ^(AFHTTPRequestOperation *operation, NSError *error){
        
        if (error) {
            NSLog(@"%@", error);
            
            NSString *respMsg = error.description;
            if (NotNil(error.userInfo, NSLocalizedDescriptionKey)) {
                respMsg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
            }
            
            NSDictionary *usrInfo = @{NOTIFICATION_MESSAGE:respMsg};
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_UI_AUTO_PROMPT
                                                                object:nil
                                                              userInfo:usrInfo];
        }
        
        if (failure) {
            failure(operation, error);
        }
    };
    
    return reqFailure;
}

-(AFHTTPRequestOperation *)AFGET:(NSString *)URLString parameters:(id)parameters success:(void (^)(AFHTTPRequestOperation *, id))success failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure{
    return [super GET:URLString parameters:parameters success:success failure:failure];
}

-(AFHTTPRequestOperation *)AFPOST:(NSString *)URLString parameters:(id)parameters success:(void (^)(AFHTTPRequestOperation *, id))success failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure{
    return [super POST:URLString parameters:parameters success:success failure:failure];
}


-(AFHTTPRequestOperation *)GET:(NSString *)URLString parameters:(id)parameters success:(void (^)(AFHTTPRequestOperation *, id))success failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure{
    
    return [super GET:URLString parameters:parameters
              success:[self extendAFHTTPRequestSuccess:success reqFailure:failure]
              failure:[self extendAFHTTPRequestFailure:failure]];
}

-(AFHTTPRequestOperation *)POST:(NSString *)URLString parameters:(id)parameters success:(void (^)(AFHTTPRequestOperation *, id))success failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure{
    
    return [super POST:URLString parameters:parameters
               success:[self extendAFHTTPRequestSuccess:success reqFailure:failure]
               failure:[self extendAFHTTPRequestFailure:failure]];
}


@end
