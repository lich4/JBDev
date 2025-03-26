#include <substrate.h>
#include <dlfcn.h>
#include "jbdev.h"

static BOOL isJBDev(NSString* pkgPath) {
    // pkgPath:
    //  /var/mobile/Media/PublicStaging/xx.app
    //  /var/mobile/Media/PublicStaging/xx.app_sparse.ipa
    @autoreleasepool {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        __block int ret_status = -1;
        __block int pkg_type = PKG_TYPE_APP;
        setIPCHandler(@"jbdev.res.info_pkg", ^(NSString* name, NSDictionary* info) {
            @autoreleasepool {
                setIPCHandler(@"jbdev.res.info_pkg", ^(NSString* name, NSDictionary* info) {});
                NSNumber* status = info[@"status"];
                ret_status = status.intValue;
                if (status.intValue == 0) {
                    NSNumber* data = info[@"data"];
                    pkg_type = data.intValue;
                } else {
                    NSLog(@"%@ isJBDev info_pkg err %@", log_prefix, status);
                }
                dispatch_semaphore_signal(sema);
            }
        });
        sendIPC(@"jbdev.req.info_pkg", @{
            @"pkg_path": pkgPath
        });
        dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC)); // 1sec is enough
        if (ret_status == -1) { // timeout, fallback to origin
            NSLog(@"%@ isJBDev info_pkg timeout", log_prefix);
            return NO;
        } else if (pkg_type == PKG_TYPE_APP) {
            NSLog(@"%@ isJBDev info_pkg skip app", log_prefix);
            return NO;
        }
        return YES;
    }
}

static void (*old_MIClientConnection_installURL_withOptions_completion)(Class cls, SEL sel, NSURL* url, NSDictionary* options, void(^block)(NSDictionary* receipt, NSError* err)) = 0;
static void new_MIClientConnection_installURL_withOptions_completion(Class cls, SEL sel, NSURL* url, NSDictionary* options, void(^block)(NSDictionary* receipt, NSError* err)) {
    @autoreleasepool {
        NSString* pkgPath = url.path;
        NSLog(@"%@ MIClientConnection installURL %@", log_prefix, pkgPath);
        MIClientConnection* conn = (MIClientConnection*)cls;
        if (!isJBDev(pkgPath)) {
            old_MIClientConnection_installURL_withOptions_completion(cls, sel, url, options, block); // 放行给AppSync处理
            return;
        }
        __block BOOL handled = NO;
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        setIPCHandler(@"jbdev.res.inst_pkg", ^(NSString* name, NSDictionary* info) { // installd安装是顺序的，所以这里不做同步处理
            @autoreleasepool {
                setIPCHandler(@"jbdev.res.inst_pkg", ^(NSString* name, NSDictionary* info) {});
                handled = YES;
                dispatch_semaphore_signal(sema);
                NSNumber* status = info[@"status"];
                if (status.intValue == 0) {
                    NSDictionary* receipt = @{
                        @"InstalledAppInfoArray": @[
                            info[@"data"]
                        ],
                    };
                    [conn sendDelegateMessagesComplete];
                    block(receipt, nil);
                } else {
                    NSError* err = [NSError errorWithDomain:@"jbdev" code:status.intValue userInfo:nil];
                    [conn sendDelegateMessagesComplete];
                    block(nil, err);
                }
            }
        });
        sendIPC(@"jbdev.req.inst_pkg", @{ // installd -> jbdev_daemons
            @"pkg_path": pkgPath
        });
        dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC));
        if (!handled) {
            NSLog(@"%@ MIClientConnection inst_pkg timeout", log_prefix);
            old_MIClientConnection_installURL_withOptions_completion(cls, sel, url, options, block);
        }
    }
}

static void (*old_MIClientConnection_installURL_identity_targetingDomain_options_returningResultInfo_completion)(Class cls, SEL sel, NSURL* url, id identity, uint64_t domain, NSDictionary* options, BOOL retResult, void(^block)(BOOL hasReceipt, NSArray* receipt, id promise, NSError* err)) = 0;
static void new_MIClientConnection_installURL_identity_targetingDomain_options_returningResultInfo_completion(Class cls, SEL sel, NSURL* url, id identity, uint64_t domain, NSDictionary* options, BOOL retResult, void(^block)(BOOL hasReceipt, NSArray* receipt, id promise, NSError* err)) {
    @autoreleasepool {
        NSString* pkgPath = url.path;
        NSLog(@"%@ MIClientConnection installURL %@", log_prefix, pkgPath);
        MIClientConnection* conn = (MIClientConnection*)cls;
        if (!isJBDev(pkgPath)) {
            old_MIClientConnection_installURL_identity_targetingDomain_options_returningResultInfo_completion(cls, sel, url, identity, domain, options, retResult, block);
            return;
        }
        __block BOOL handled = NO;
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        setIPCHandler(@"jbdev.res.inst_pkg", ^(NSString* name, NSDictionary* info) {
            @autoreleasepool {
                setIPCHandler(@"jbdev.res.inst_pkg", ^(NSString* name, NSDictionary* info) {});
                handled = YES;
                dispatch_semaphore_signal(sema);
                NSNumber* status = info[@"status"];
                if (status.intValue == 0) {
                    [conn sendDelegateMessagesComplete];
                    block(YES, info[@"data"], nil, nil);
                } else {
                    NSError* err = [NSError errorWithDomain:@"jbdev" code:status.intValue userInfo:nil];
                    [conn sendDelegateMessagesComplete];
                    NSLog(@"%@ MIClientConnection inst_pkg err %@", log_prefix, status);
                    block(NO, nil, nil, err);
                }
            }
        });
        sendIPC(@"jbdev.req.inst_pkg", @{
            @"pkg_path": pkgPath
        });
        dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC));
        if (!handled) { // timeout
            old_MIClientConnection_installURL_identity_targetingDomain_options_returningResultInfo_completion(cls, sel, url, identity, domain, options, retResult, block);
        }
    }
}

static Boolean (*old_SMJobSubmit)(CFStringRef domain, CFDictionaryRef job, CFTypeID auth, CFErrorRef* outError) = 0;
static Boolean new_SMJobSubmit(CFStringRef domain, CFDictionaryRef job, CFTypeID auth, CFErrorRef* outError) {
    @autoreleasepool {
        NSMutableDictionary* mjob = [(__bridge NSDictionary*)job mutableCopy];
        if (job != nil && mjob[@"ProgramArguments"] != nil) {
            NSArray* argv = mjob[@"ProgramArguments"];
            NSString* path = argv.firstObject;
            NSOperatingSystemVersion sysver = NSProcessInfo.processInfo.operatingSystemVersion;
            int mv = (int)sysver.majorVersion;
            if ([path isEqualToString:@"/Developer/usr/bin/debugserver"] ||
                    [path isEqualToString:@"/usr/libexec/debugserver"]) { // iOS16+
                NSMutableArray* margv = [argv mutableCopy];
                if (mv == 12) {
                    margv[0] = @(JBROOT("/usr/bin/debugserver_azj12"));
                } else if (mv == 13 || mv == 14) {
                    margv[0] = @(JBROOT("/usr/bin/debugserver_azj14"));
                } else if (mv == 15 || mv == 16) {
                    margv[0] = @(JBROOT("/usr/bin/debugserver_azj15"));
                } else {
                    NSLog(@"%@ unsupported iOS version:%d", log_prefix, mv);
                }
                mjob[@"UserName"] = @"root";
                mjob[@"ProgramArguments"] = margv;
                job = (__bridge_retained CFDictionaryRef)mjob;
            }
        }
        return old_SMJobSubmit(domain, job, auth, outError);
    }
}

class Ctor {
public:
    Ctor() {
        if (0 == strcmp(__progname, "installd")) {
            Class MIClientConnection = objc_getClass("MIClientConnection");
            if (MIClientConnection != nil) {
                if ([MIClientConnection instancesRespondToSelector:@selector(installURL:withOptions:completion:)]) {
                    MSHookMessageEx(MIClientConnection, @selector(installURL:withOptions:completion:),
                        (IMP)new_MIClientConnection_installURL_withOptions_completion,
                        (IMP*)&old_MIClientConnection_installURL_withOptions_completion);
                } else if ([MIClientConnection instancesRespondToSelector:@selector(installURL:identity:targetingDomain:options:returningResultInfo:completion:)]) {
                    // for iOS16+
                    MSHookMessageEx(MIClientConnection,
                        @selector(installURL:identity:targetingDomain:options:returningResultInfo:completion:),
                        (IMP)new_MIClientConnection_installURL_identity_targetingDomain_options_returningResultInfo_completion,
                        (IMP*)&old_MIClientConnection_installURL_identity_targetingDomain_options_returningResultInfo_completion);
                }
            }
        } else if (0 == strcmp(__progname, "lockdownd")) {
            void* SMJobSubmit = dlsym(RTLD_DEFAULT, "SMJobSubmit");
            MSHookFunction((void*)SMJobSubmit, (void*)new_SMJobSubmit, (void**)&old_SMJobSubmit);
        }
    }
} ctor;

