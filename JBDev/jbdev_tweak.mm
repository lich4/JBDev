#include <substrate.h>
#include <dlfcn.h>
#include "jbdev.h"

enum InstallTargetType {
    NormalTarget                    = 1,    // Developer/System/Customer
    PlaceholderTarget               = 2,
    DowngradeToPlaceholderTarget    = 3,
};

@interface MIInstallOptions : NSObject
- (unsigned)installTargetType;
- (NSString*)bundleIdentifier;
- (NSDictionary*)legacyOptionsDictionary;
- (unsigned)lsInstallType;
- (BOOL)isDeveloperInstall;
- (BOOL)isSystemAppInstall;
@end

@interface IXAppInstallCoordinator : NSObject
- (void)installApplication:(NSURL*)bundleURL consumeSource:(BOOL)consumeSource options:(MIInstallOptions*)options
    legacyProgressBlock:(void(^)(NSError* err))progressBlock completion:(void(^)(NSString* bid, NSError* err))completion;
@end

@interface LSApplicationWorkspace : NSObject
- (BOOL)installApplication:(NSURL*)bundleURL withOptions:(NSDictionary*)options error:(NSError**)error 
    usingBlock:(void(^)(NSError* err))block;
@end

static NSDictionary* getPkgInfo(NSString* pkgPath) {
    // pkgPath:
    //  /var/mobile/Media/PublicStaging/xx.app
    //  /var/mobile/Media/PublicStaging/xx.app_sparse.ipa
    @autoreleasepool {
        __block NSDictionary* result = nil;
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        __block BOOL handled = NO;
        setIPCHandler(@"jbdev.res.info_pkg", ^(NSString* name, NSDictionary* info) {
            @autoreleasepool {
                setIPCHandler(@"jbdev.res.info_pkg", ^(NSString* name, NSDictionary* info) {});
                NSNumber* status = info[@"status"];
                if (status.intValue == 0) {
                    result = [info[@"data"] copy];
                }
                handled = YES;
                dispatch_semaphore_signal(sema);
            }
        });
        sendIPC(@"jbdev.req.info_pkg", @{
            @"pkg_path": pkgPath
        });
        dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC)); // 1sec is enough
        if (!handled) { // timeout, fallback to origin
            NSLog(@"%@ getPkgInfo timeout", log_prefix);
            return nil;
        }
        return result;
    }
}

static BOOL isJBDev(NSDictionary* infoDic) {
    @autoreleasepool {
        if (infoDic == nil || infoDic[@"jbdev"] == nil) {
            return NO;
        }
        NSDictionary* jbdevDic = infoDic[@"jbdev"];
        NSString* pkgType = [jbdevDic[@"type"] lowercaseString];
        if ([pkgType isEqualToString:@"jailbreak"] || [pkgType isEqualToString:@"trollstore"]) {
            return YES;
        }
        return NO;
    }
}

static int instPkg(NSString* pkgPath) {
    @autoreleasepool {
        __block int result = -1;
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        setIPCHandler(@"jbdev.res.inst_pkg", ^(NSString* name, NSDictionary* info) {
            @autoreleasepool {
                setIPCHandler(@"jbdev.res.inst_pkg", ^(NSString* name, NSDictionary* info) {});
                NSNumber* status = info[@"status"];
                if (status.intValue == 0) {
                    result = 1;
                } else {
                    result = 0;
                }
                dispatch_semaphore_signal(sema);
            }
        });
        sendIPC(@"jbdev.req.inst_pkg", @{ // streaming_zip_conduit -> jbdev_daemons
            @"pkg_path": pkgPath
        });
        dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC));
        if (result == -1) { // timeout, fallback to origin
            NSLog(@"%@ instPkg timeout", log_prefix);
        }
        return result;
    }
}

static BOOL (*old_LSApplicationWorkspace_installApplication_withOptions_error_usingBlock)(
    Class cls, SEL sel, NSURL* bundleURL, NSDictionary* options, NSError** error, void(^block)(NSError* err)) = 0;
static BOOL new_LSApplicationWorkspace_installApplication_withOptions_error_usingBlock(
    Class cls, SEL sel, NSURL* bundleURL, NSDictionary* options, NSError** error, void(^block)(NSError* err)) {
    @autoreleasepool {
        if (![options[@"PackageType"] isEqualToString:@"Developer"]) {
            return old_LSApplicationWorkspace_installApplication_withOptions_error_usingBlock(
                cls, sel, bundleURL, options, error, block);
        }
        NSString* bundlePath = bundleURL.path;
        NSDictionary* infoDic = getPkgInfo(bundlePath);
        if (!isJBDev(infoDic)) { // 放行给AppSync处理
            return old_LSApplicationWorkspace_installApplication_withOptions_error_usingBlock(
                cls, sel, bundleURL, options, error, block);
        }
        int status = instPkg(bundlePath);
        if (status == 0) {
            NSError* err = [NSError errorWithDomain:@"jbdev" code:0x1000 userInfo:nil];
            block(err);
            NSLog(@"%@ installApplication err", log_prefix);
            return NO;
        } else if (status == 1) {
            NSLog(@"%@ installApplication suc", log_prefix);
            return YES;
        }
        return old_LSApplicationWorkspace_installApplication_withOptions_error_usingBlock(
            cls, sel, bundleURL, options, error, block);
    }
}

static void (*old_IXAppInstallCoordinator_installApplication_consumeSource_options_legacyProgressBlock_completion)(
    Class cls, SEL sel, NSURL* bundleURL, BOOL consumeSource, MIInstallOptions* options, void(^progressBlock)(NSError* err), 
    void(^completion)(NSString* bid, NSError* err)) = 0;
static void new_IXAppInstallCoordinator_installApplication_consumeSource_options_legacyProgressBlock_completion(
    Class cls, SEL sel, NSURL* bundleURL, BOOL consumeSource, MIInstallOptions* options, void(^progressBlock)(NSError* err), 
    void(^completion)(NSString* bid, NSError* err)) {
    @autoreleasepool {
        if (!options.isDeveloperInstall) {
            return old_IXAppInstallCoordinator_installApplication_consumeSource_options_legacyProgressBlock_completion(
                cls, sel, bundleURL, consumeSource, options, progressBlock, completion);
        }
        NSString* bundlePath = bundleURL.path;
        NSDictionary* infoDic = getPkgInfo(bundlePath);
        if (!isJBDev(infoDic)) { // 放行给AppSync处理
            return old_IXAppInstallCoordinator_installApplication_consumeSource_options_legacyProgressBlock_completion(
                cls, sel, bundleURL, consumeSource, options, progressBlock, completion);
        }
        int status = instPkg(bundlePath);
        if (status == 0) {
            NSError* err = [NSError errorWithDomain:@"jbdev" code:0x1000 userInfo:nil];
            NSLog(@"%@ installApplication err", log_prefix);
            return completion(nil, err);
        } else if (status == 1) {
            NSString* bid = infoDic[@"CFBundleIdentifier"];
            NSLog(@"%@ installApplication suc", log_prefix);
            return completion(bid, nil);
        }
        return old_IXAppInstallCoordinator_installApplication_consumeSource_options_legacyProgressBlock_completion(
            cls, sel, bundleURL, consumeSource, options, progressBlock, completion);
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
                } else if (mv >= 15) {
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
        if (0 == strcmp(__progname, "streaming_zip_conduit")) {
            Class IXAppInstallCoordinator = objc_getClass("IXAppInstallCoordinator");
            if (IXAppInstallCoordinator != nil) { // iOS16+
                if ([IXAppInstallCoordinator respondsToSelector:@selector(installApplication:consumeSource:options:legacyProgressBlock:completion:)]) {
                    MSHookMessageEx(object_getClass(IXAppInstallCoordinator), 
                        @selector(installApplication:consumeSource:options:legacyProgressBlock:completion:),
                        (IMP)new_IXAppInstallCoordinator_installApplication_consumeSource_options_legacyProgressBlock_completion,
                        (IMP*)&old_IXAppInstallCoordinator_installApplication_consumeSource_options_legacyProgressBlock_completion);
                }
            } else {
                Class LSApplicationWorkspace = objc_getClass("LSApplicationWorkspace");
                if (LSApplicationWorkspace != nil) {
                    if ([LSApplicationWorkspace instancesRespondToSelector:@selector(installApplication:withOptions:error:usingBlock:)]) {
                        MSHookMessageEx(LSApplicationWorkspace, 
                            @selector(installApplication:withOptions:error:usingBlock:),
                            (IMP)new_LSApplicationWorkspace_installApplication_withOptions_error_usingBlock,
                            (IMP*)&old_LSApplicationWorkspace_installApplication_withOptions_error_usingBlock);
                    }
                }
            }
        } else if (0 == strcmp(__progname, "lockdownd")) {
            void* SMJobSubmit = dlsym(RTLD_DEFAULT, "SMJobSubmit");
            MSHookFunction((void*)SMJobSubmit, (void*)new_SMJobSubmit, (void**)&old_SMJobSubmit);
        }
    }
} ctor;

