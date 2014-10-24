//
//  CPHTTPRequestManager.h
//  B2A
//
//  Created by Bob on 9/17/14.
//  Copyright (c) 2014 chinapnr. All rights reserved.
//

#import "AFHTTPRequestOperationManager.h"

#define RESP_CODE @"resp_code"

BOOL NotNil(id dict, NSString *k);
BOOL NotNilAndEqualsValue(id dict, NSString *k, NSString *value);

typedef NSString * (^AFQueryStringSerializationBlock)(NSURLRequest *request, NSDictionary *parameters, NSError *__autoreleasing *error);

@interface CPHTTPRequestManager : AFHTTPRequestOperationManager

+(instancetype)sharedInstance:(NSString *)host_url;

@property (nonatomic, copy) NSString *sessionId;
@property (nonatomic, copy) AFQueryStringSerializationBlock querySerializationBlock;


-(instancetype)initWithBaseURL:(NSURL *)url;

-(AFHTTPRequestOperation *)AFGET:(NSString *)URLString parameters:(id)parameters success:(void (^)(AFHTTPRequestOperation *, id))success failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure;

-(AFHTTPRequestOperation *)AFPOST:(NSString *)URLString parameters:(id)parameters success:(void (^)(AFHTTPRequestOperation *, id))success failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure;


-(AFHTTPRequestOperation *)GET:(NSString *)URLString parameters:(id)parameters success:(void (^)(AFHTTPRequestOperation *, id))success failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure;

-(AFHTTPRequestOperation *)POST:(NSString *)URLString parameters:(id)parameters success:(void (^)(AFHTTPRequestOperation *, id))success failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure;

@end
