// OVCHTTPSessionManager.m
//
// Copyright (c) 2013-2016 Overcoat Team
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "OVCHTTPSessionManager.h"
#import "OVCResponse.h"
#import "OVCModelResponseSerializer.h"
#import "OVCURLMatcher.h"
#import "NSError+OVCResponse.h"

@interface OVCHTTPSessionManager ()

#pragma mark - Pagination

@property (copy, atomic, OVC_NULLABLE) NSMutableDictionary OVCGenerics(NSString *, NSMutableDictionary OVCGenerics(NSNumber *, NSURLSessionDataTask *) *) *paginatedResourcesTasks;
@property (copy, atomic, OVC_NULLABLE) NSMutableDictionary OVCGenerics(NSString *, NSMutableArray OVCGenerics(NSURLSessionDataTask *) *) *paginatedResourcesTasksQueues;

@end

@implementation OVCHTTPSessionManager

#if DEBUG
+ (void)initialize {
    // TODO: Add links to releated document.
    if ([self respondsToSelector:@selector(errorModelClass)]) {
        NSLog(@"Warning: `+[OVCHTTPSessionManager errorModelClass]` is deprecated. "
              @"Override `+[OVCHTTPSessionManager errorModelClassesByResourcePath]` instead. (Class: %@)", self);
    }
    if ([self respondsToSelector:@selector(responseClass)]) {
        NSLog(@"Warning: `+[OVCHTTPSessionManager responseClass]` is deprecated. "
              @"Override `+[OVCHTTPSessionManager responseClassesByResourcePath]` instead. (Class: %@)", self);
    }
}
#endif

- (instancetype)initWithBaseURL:(NSURL *)url sessionConfiguration:(NSURLSessionConfiguration *)configuration {
    if (self = [super initWithBaseURL:url sessionConfiguration:configuration]) {
        self.responseSerializer =
        [OVCModelResponseSerializer
         serializerWithURLMatcher:[OVCURLMatcher matcherWithBasePath:self.baseURL.path
                                                  modelClassesByPath:[[self class] modelClassesByResourcePath]]
         responseClassURLMatcher:[OVCURLMatcher matcherWithBasePath:self.baseURL.path
                                                 modelClassesByPath:[[self class] responseClassesByResourcePath]]
         errorModelClassURLMatcher:[OVCURLMatcher matcherWithBasePath:self.baseURL.path
                                                   modelClassesByPath:[[self class] errorModelClassesByResourcePath]]];
    }
    return self;
}

#pragma mark - HTTP Manager Protocol

+ (NSDictionary *)modelClassesByResourcePath {
    [NSException
     raise:NSInternalInconsistencyException
     format:@"+[%@ %@] should be overridden by subclass", NSStringFromClass(self), NSStringFromSelector(_cmd)];
    return nil;  // Not reached
}

+ (NSDictionary *)responseClassesByResourcePath {
    return @{@"**": [OVCResponse class]};
}

+ (NSDictionary *)errorModelClassesByResourcePath {
    return nil;
}

#pragma mark - Pagination

+ (NSString *)paginatedResourcePath:(NSString *)resourcePath
                            forPage:(NSUInteger)page {
    return resourcePath;
}

- (NSMutableDictionary OVCGenerics(NSString *, NSMutableDictionary OVCGenerics(NSNumber *, NSURLSessionDataTask *) *) *)paginatedResourcesTasks {

    if (! self->_paginatedResourcesTasks) {
        self->_paginatedResourcesTasks = [NSMutableDictionary new];
    }
    return self->_paginatedResourcesTasks;
}

- (NSMutableDictionary OVCGenerics(NSString *, NSMutableArray OVCGenerics(NSURLSessionDataTask *) *) *)paginatedResourcesTasksQueues {

    if (! self->_paginatedResourcesTasksQueues) {
        self->_paginatedResourcesTasksQueues = [NSMutableDictionary new];
    }
    return self->_paginatedResourcesTasksQueues;
}

- (NSURLSessionDataTask *)GET:(NSString *)URLString
                   parameters:(id)parameters
                         page:(NSUInteger)page
                     progress:(void (^)(NSProgress *downloadProgress))downloadProgress
                   completion:(void (^)(OVCResponse *, NSError *))completion {

    __block NSURLSessionDataTask *task = self.paginatedResourcesTasks[URLString][@(page)];

    if (! task) {
        task = [self _dataTaskWithHTTPMethod:@"GET"
                                   URLString:[[self class] paginatedResourcePath:URLString
                                                                         forPage:page]
                                  parameters:parameters
                              uploadProgress:nil
                            downloadProgress:downloadProgress
                                  completion:
                ^(OVCResponse * _Nullable response, NSError * _Nullable error) {

                    if (completion) {
                        completion(response, error);
                    }
                    [self.paginatedResourcesTasksQueues[URLString] removeObject:task];
                    [self.paginatedResourcesTasks[URLString] removeObjectForKey:@(page)];

                    self.paginatedResourcesTasksQueues[URLString].lastObject.priority = NSURLSessionTaskPriorityHigh;

                    if (self.paginatedResourcesTasksQueues[URLString].count == 0) {
                        [self.paginatedResourcesTasksQueues removeObjectForKey:URLString];
                    }
                    if (self.paginatedResourcesTasks[URLString].allValues.count == 0) {
                        [self.paginatedResourcesTasks removeObjectForKey:URLString];
                    }
                    if (self.paginatedResourcesTasksQueues.allValues.count == 0) {
                        self.paginatedResourcesTasksQueues = nil;
                    }
                    if (self.paginatedResourcesTasks.allValues.count == 0) {
                        self.paginatedResourcesTasks = nil;
                    }
                }];
        if (! [self.paginatedResourcesTasks[URLString] isKindOfClass:[NSMutableDictionary class]]) {
            self.paginatedResourcesTasks[URLString] = [NSMutableDictionary new];
        }
        self.paginatedResourcesTasks[URLString][@(page)] = task;
        [task resume];
    } else {
        [self.paginatedResourcesTasksQueues[URLString] removeObject:task];
    }
    if (! [self.paginatedResourcesTasksQueues[URLString] isKindOfClass:[NSMutableArray class]]) {
        self.paginatedResourcesTasksQueues[URLString] = [NSMutableArray new];
    }
    self.paginatedResourcesTasksQueues[URLString].lastObject.priority = NSURLSessionTaskPriorityLow;
    task.priority = NSURLSessionTaskPriorityHigh;
    [self.paginatedResourcesTasksQueues[URLString] addObject:task];

    return task;
}

#pragma mark - Making requests

- (NSURLSessionDataTask *)_dataTaskWithHTTPMethod:(NSString *)method
                                        URLString:(NSString *)URLString
                                       parameters:(id)parameters
                                   uploadProgress:(void (^)(NSProgress *uploadProgress))uploadProgress
                                 downloadProgress:(void (^)(NSProgress *downloadProgress))downloadProgress
                                       completion:(void (^)(OVCResponse *, NSError *))completion {
    // The implementation is copied from AFNetworking ... (Since we want to pass `responseObject`)
    // (Superclass implemenration doesn't return response object.)

    NSError *serializationError = nil;
    NSMutableURLRequest *request = [self.requestSerializer
                                    requestWithMethod:method
                                    URLString:[NSURL URLWithString:URLString relativeToURL:self.baseURL].absoluteString
                                    parameters:parameters
                                    error:&serializationError];
    if (serializationError) {
        if (completion) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
            dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
                completion(nil, serializationError);
            });
#pragma clang diagnostic pop
        }
        return nil;
    }

    return [self dataTaskWithRequest:request
                      uploadProgress:uploadProgress
                    downloadProgress:downloadProgress
                   completionHandler:^(NSURLResponse * __unused response, id responseObject, NSError *error) {
                       if (completion) {
                           if (!error) {
                               completion(responseObject, nil);
                           } else {
                               error = [error ovc_errorWithUnderlyingResponse:responseObject];
                               completion(responseObject, error);
                           }
                       }
                   }];
}

- (NSURLSessionDataTask *)GET:(NSString *)URLString
                   parameters:(id)parameters
                   completion:(void (^)(OVCResponse *, NSError *))completion {
    NSURLSessionDataTask *task = [self GET:URLString
                                parameters:parameters
                                  progress:nil
                                completion:completion];
    return task;
}

- (NSURLSessionDataTask *)GET:(NSString *)URLString
                   parameters:(id)parameters
                     progress:(void (^)(NSProgress *downloadProgress))downloadProgress
                   completion:(void (^)(OVCResponse *, NSError *))completion {
    NSURLSessionDataTask *task = [self _dataTaskWithHTTPMethod:@"GET"
                                                     URLString:URLString
                                                    parameters:parameters
                                                uploadProgress:nil
                                              downloadProgress:downloadProgress
                                                    completion:completion];
    [task resume];
    return task;
}

- (NSURLSessionDataTask *)HEAD:(NSString *)URLString
                    parameters:(id)parameters
                    completion:(void (^)(OVCResponse *, NSError *))completion {
    NSURLSessionDataTask *task = [self _dataTaskWithHTTPMethod:@"HEAD"
                                                     URLString:URLString
                                                    parameters:parameters
                                                uploadProgress:nil
                                              downloadProgress:nil
                                                    completion:completion];
    [task resume];
    return task;
}

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(id)parameters
                    completion:(void (^)(OVCResponse *, NSError *))completion {
    NSURLSessionDataTask *task = [self _dataTaskWithHTTPMethod:@"POST"
                                                     URLString:URLString
                                                    parameters:parameters
                                                uploadProgress:nil
                                              downloadProgress:nil
                                                    completion:completion];
    [task resume];
    return task;
}

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(id)parameters
     constructingBodyWithBlock:(void (^)(id<AFMultipartFormData>))block
                    completion:(void (^)(OVCResponse *, NSError *))completion {
        NSURLSessionDataTask *task = [self POST:URLString
                                     parameters:parameters
                      constructingBodyWithBlock:block
                                       progress:nil
                                     completion:completion];
    return task;
}

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(id)parameters
                      progress:(void (^)(NSProgress *uploadProgress))uploadProgress
                    completion:(void (^)(OVCResponse *, NSError *))completion {
    NSURLSessionDataTask *task = [self _dataTaskWithHTTPMethod:@"POST"
                                                     URLString:URLString
                                                    parameters:parameters
                                                uploadProgress:uploadProgress
                                              downloadProgress:nil
                                                    completion:completion];
    [task resume];
    return task;
}

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(id)parameters
     constructingBodyWithBlock:(void (^)(id<AFMultipartFormData> formData))block
                      progress:(void (^)(NSProgress *uploadProgress))uploadProgress
                    completion:(void (^)(OVCResponse *, NSError *))completion {
    // The implementation is copied from AFNetworking ... (Since we want to pass `responseObject`)
    // (Superclass implemenration doesn't return response object.)

    NSError *serializationError = nil;
    NSMutableURLRequest *request = [self.requestSerializer
                                    multipartFormRequestWithMethod:@"POST"
                                    URLString:[NSURL URLWithString:URLString relativeToURL:self.baseURL].absoluteString
                                    parameters:parameters
                                    constructingBodyWithBlock:block
                                    error:&serializationError];
    if (serializationError) {
        if (completion) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
            dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
                completion(nil, serializationError);
            });
#pragma clang diagnostic pop
        }
        return nil;
    }

    // `dataTaskWithRequest:completionHandler:` creates a new NSURLSessionDataTask
    NSURLSessionDataTask *dataTask = [self uploadTaskWithStreamedRequest:request
                                                                progress:uploadProgress
                                                       completionHandler:^(NSURLResponse * __unused response,
                                                                           id responseObject,
                                                                           NSError *error) {
                                                           if (completion) {
                                                               if (!error) {
                                                                   completion(responseObject, nil);
                                                               } else {
                                                                   completion(responseObject, error);
                                                               }
                                                           }
                                                       }];

    [dataTask resume];
    return dataTask;
}

- (NSURLSessionDataTask *)PUT:(NSString *)URLString
                   parameters:(id)parameters
                   completion:(void (^)(OVCResponse *, NSError *))completion {
    NSURLSessionDataTask *task = [self _dataTaskWithHTTPMethod:@"PUT"
                                                     URLString:URLString
                                                    parameters:parameters
                                                uploadProgress:nil
                                              downloadProgress:nil
                                                    completion:completion];
    [task resume];
    return task;
}

- (NSURLSessionDataTask *)PATCH:(NSString *)URLString
                     parameters:(id)parameters
                     completion:(void (^)(OVCResponse *, NSError *))completion {
    NSURLSessionDataTask *task = [self _dataTaskWithHTTPMethod:@"PATCH"
                                                     URLString:URLString
                                                    parameters:parameters
                                                uploadProgress:nil
                                              downloadProgress:nil
                                                    completion:completion];
    [task resume];
    return task;
}

- (NSURLSessionDataTask *)DELETE:(NSString *)URLString
                      parameters:(id)parameters
                      completion:(void (^)(OVCResponse *, NSError *))completion {
    NSURLSessionDataTask *task = [self _dataTaskWithHTTPMethod:@"DELETE"
                                                     URLString:URLString
                                                    parameters:parameters
                                                uploadProgress:nil
                                              downloadProgress:nil
                                                    completion:completion];
    [task resume];
    return task;
}

@end
