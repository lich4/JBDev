#ifndef JBDEV_H
#define JBDEV_H

#if defined(THEOS_PACKAGE_SCHEME_ROOTLESS)
#include <rootless.h>
#define JBROOT(X)   "/var/jb" X
#elif defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
#include <roothide.h>
#define JBROOT(X)   jbroot(X)
#else
#define JBROOT(X)   X
#endif

#import <Foundation/Foundation.h>
#include "utils.h"

#define PRODUCT         "JBDev"

enum PKG_TYPE {
    PKG_TYPE_APP,           // 普通App
    PKG_TYPE_JAILBREAK,     // 越狱App
    PKG_TYPE_TROLLSTORE,    // 巨魔App
};

@interface MIClientConnection: NSObject
- (void)sendDelegateMessagesComplete;
- (void)installURL:(NSURL*)url withOptions:(NSDictionary*)options completion:(void(^)(NSDictionary* receipt, NSError* err))block;
- (void)installURL:(NSURL*)url identity:(id)identity targetingDomain:(uint64_t)domain options:(NSDictionary*)options returningResultInfo:(BOOL)retResult completion:(void(^)(BOOL hasReceipt, NSArray* receipt, id promise, NSError* err))block;
@end

extern const char* __progname;
static NSString* log_prefix = @PRODUCT;
static NSString* log_path   = @"/tmp/jbdev.log";
 
#endif // JBDEV_H

