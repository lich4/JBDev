#include "jbdev.h"

@interface LSBundleProxy : NSObject
+ (instancetype)bundleProxyForIdentifier:(NSString*)bid;
+ (instancetype)bundleProxyForURL:(NSURL*)url;
@property (nonatomic, readonly) NSURL*          bundleContainerURL;
@property (nonatomic, readonly) NSString*       bundleExecutable;
@property (nonatomic, readonly) NSString*       bundleIdentifier;
@property (nonatomic, readonly) NSString*       bundleType;
@property (nonatomic, readonly) NSString*       bundleVersion;
@property (nonatomic, readonly) NSURL*          bundleURL; //安装路径
@property (nonatomic, readonly) NSURL*          containerURL; // 沙盒路径
@property (nonatomic, readonly) NSDictionary*   entitlements;
@property (nonatomic, readonly) NSDictionary*   environmentVariables;
@property (nonatomic, readonly) NSDictionary<NSString*,NSURL*>* groupContainerURLs;
@property (nonatomic, readonly) BOOL            isContainerized;
@property (nonatomic, readonly) NSString*       localizedShortName;
@property (nonatomic, readonly) NSString*       signerIdentity;
@property (nonatomic, readonly) NSString*       signerOrganization;
- (id)objectForInfoDictionaryKey:(NSString*)key ofClass:(Class)cls;
@end

@interface LSApplicationProxy : LSBundleProxy
@property (nonatomic, readonly) NSString*       applicationDSID;
@property (nonatomic, readonly) NSString*       applicationIdentifier;
@property (nonatomic, readonly) NSString*       applicationType;
@property (nonatomic, readonly) NSNumber*       downloaderDSID;
@property (nonatomic, readonly) BOOL            freeProfileValidated;
@property (nonatomic, readonly) int             installType;
@property (nonatomic, readonly) BOOL            profileValidated;
@property (nonatomic, readonly) NSDate*         registeredDate;
@property (nonatomic, readonly) NSNumber*       staticDiskUsage;
@property (nonatomic, readonly) NSString*       vendorName;
@end

@interface LSApplicationWorkspace
+ (instancetype)defaultWorkspace;
- (BOOL)registerApplication:(NSURL*)bundleURL;
- (BOOL)registerApplicationDictionary:(NSDictionary*)dic; // iOS>=7
- (BOOL)unregisterApplication:(NSURL*)bundleURL;
- (NSArray*)allApplications;
@end

static BOOL isAppInstalled(NSString* appBid) {
    LSApplicationProxy* proxy = [LSApplicationProxy bundleProxyForIdentifier:appBid];
    return proxy != nil && proxy.bundleURL != nil;
}

static BOOL isBundlePathValid(NSString* bundlePath) {
    NSString* infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
    if (![NSFileManager.defaultManager fileExistsAtPath:infoPath]) {
        return NO;
    }
    NSDictionary* infoDic = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    if (infoDic[@"CFBundleIdentifier"] == nil || infoDic[@"CFBundleExecutable"] == nil) {
        return NO;
    }
    NSString* exePath = [bundlePath stringByAppendingPathComponent:infoDic[@"CFBundleExecutable"]];
    if (![NSFileManager.defaultManager fileExistsAtPath:exePath]) {
        return NO;
    }
    return YES;
}

NSDictionary* getAppInfo(NSString* appBid) {
    @autoreleasepool {
        LSApplicationProxy* proxy = [LSApplicationProxy bundleProxyForIdentifier:appBid];
        NSDictionary* groupContainerURLs = proxy.groupContainerURLs;
        NSMutableDictionary* groupContainers = [NSMutableDictionary dictionary];
        for (NSString* key in groupContainerURLs) {
            NSURL* url = groupContainerURLs[key];
            groupContainers[key] = url.path;
        }
        NSMutableDictionary* info = [NSMutableDictionary dictionary];
        info[@"AppInstallDate"] = proxy.registeredDate.description;
        info[@"ApplicationType"] = proxy.applicationType;
        //info[@"ApplicationType"] = @"System"; ??
        info[@"BundleContainer"] = proxy.bundleContainerURL.path;
        info[@"CFBundleIdentifier"] = proxy.bundleIdentifier;
        info[@"CFBundleShortVersionString"] = [proxy objectForInfoDictionaryKey:@"CFBundleShortVersionString" ofClass:NSString.class];
        info[@"CFBundleVersion"] = proxy.bundleVersion;
        info[@"CodeInfoIdentifier"] = proxy.bundleIdentifier;
        info[@"CodeSigningInfoNotAuthoritative"] = @NO; // ??
        info[@"CompatibilityState"] = @0;
        info[@"Container"] = proxy.containerURL.path;
        info[@"Entitlements"] = proxy.entitlements;
        info[@"EnvironmentVariables"] = proxy.environmentVariables;
        info[@"FreeProfileValidated"] = @NO; //@(proxy.freeProfileValidated);
        info[@"GroupContainers"] = groupContainers;
        info[@"HasAppGroupContainers"] = @(groupContainers.count>0);
        info[@"HasSettingsBundle"] = @NO;
        info[@"HasSystemContainer"] = @NO; // ??
        info[@"HasSystemGroupContainers"] = @NO; // ??
        //info[@"InstallSessionID"] = NSData_to_NSString(randNSData(16));
        info[@"IsAdHocSigned"] = @NO;
        info[@"IsContainerized"] = @(proxy.isContainerized);
        info[@"IsDeletable"] = @YES;
        info[@"IsNoLongerCompatible"] = @NO;
        info[@"IsOnDemandInstallCapable"] = @NO;
        info[@"IsOnMountedDiskImage"] = @NO;
        info[@"IsPlaceholder"] = @NO;
        info[@"IsSwiftPlaygroundsApp"] = @NO;
        info[@"IsUpdatedSystemApp"] = @NO;
        info[@"IsWebNotificationBundle"] = @NO;
        info[@"LSInstallType"] = @(proxy.installType);
        info[@"Path"] = proxy.bundleURL.path;
        info[@"PlaceholderFailureReason"] = @0;
        info[@"ProfileValidated"] = @(proxy.profileValidated);
        info[@"SignatureVersion"] = @131328; // ??
        info[@"SignerIdentity"] = proxy.signerIdentity;
        info[@"SignerOrganization"] = proxy.signerOrganization;
        info[@"StaticDiskUsage"] = proxy.staticDiskUsage;
        info[@"UPPValidated"] = @NO;
        //info[@"UniqueInstallID"] = NSData_to_NSString(randNSData(16));
        return info;
    }
}

static NSString* getAppBundleFromPkg(NSString* pkgPath, NSString* __strong* err) {
    @autoreleasepool {
        NSString* bundlePath = nil;
        if ([NSFileManager.defaultManager fileExistsAtPath:[pkgPath stringByAppendingPathComponent:@"Info.plist"]]) {
            // /var/mobile/Media/PublicStaging/xxx.app
            bundlePath = pkgPath;
        } else if ([NSFileManager.defaultManager fileExistsAtPath:[pkgPath stringByAppendingPathComponent:@"Payload"]]) {
            // /var/mobile/Media/PublicStaging/xxx.app_sparse.ipa
            NSString* payloadPath = [pkgPath stringByAppendingPathComponent:@"Payload"];
            NSError* error = nil;
            for (NSString* item in [NSFileManager.defaultManager contentsOfDirectoryAtPath:payloadPath error:&error]) {
                if ([item hasSuffix:@".app"]) {
                    bundlePath = [payloadPath stringByAppendingPathComponent:item];
                    break;
                }
            }
        }
        if (bundlePath == nil) {
            *err = [NSString stringWithFormat:@"getAppBundleFromPkg: could not find bundle for package %@", pkgPath];
            return nil;
        }
        if (!isBundlePathValid(bundlePath)) {
            *err = [NSString stringWithFormat:@"getAppBundleFromPkg: invalid bundle %@", bundlePath];
            return nil;
        }
        return bundlePath;
    }
}

static NSDictionary* getAppInfoFromPkg(NSString* pkgPath, NSString* __strong* err) {
    @autoreleasepool {
        NSString* bundlePath = getAppBundleFromPkg(pkgPath, err);
        if (bundlePath == nil) {
            return nil;
        }
        NSString* infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
        if (![NSFileManager.defaultManager fileExistsAtPath:infoPath]) {
            *err = @"getAppInfoFromPkg: could not find Info.plist";
            return nil;
        }
        NSMutableDictionary* infoDic = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath];
        NSString* jbdevPath = [bundlePath stringByAppendingPathComponent:@"jbdev.plist"];
        if ([NSFileManager.defaultManager fileExistsAtPath:jbdevPath]) {
            NSDictionary* jbdevDic = [NSDictionary dictionaryWithContentsOfFile:jbdevPath];
            if (jbdevDic != nil) {
                infoDic[@"jbdev"] = jbdevDic;
            }
        }
        return infoDic;
    }
}

static int getPkgType(NSDictionary* jbdevDic) {
    @autoreleasepool {
        int pkg_type = PKG_TYPE_APP;
        if (jbdevDic != nil) {
            NSString* pkgType = [jbdevDic[@"type"] lowercaseString];
            if ([pkgType isEqualToString:@"jailbreak"]) {
                pkg_type = PKG_TYPE_JAILBREAK;
            } else if ([pkgType isEqualToString:@"trollstore"]) {
                pkg_type = PKG_TYPE_TROLLSTORE;
            }
        }
        return pkg_type;
    }
}

static NSString* getRootFSPath(NSString* path) {
#ifdef THEOS_PACKAGE_SCHEME_ROOTHIDE
    return @(rootfs(path.UTF8String));
#else
    return path;
#endif
}

static int instDeb(NSString* debPath, NSString* __strong* err) {
    @autoreleasepool {
        NSString* dpkgPath = @(JBROOT("/usr/bin/dpkg"));
        if (![NSFileManager.defaultManager fileExistsAtPath:dpkgPath]) {
            *err = @"instDeb: could not find dpkg";
            return -1;
        }
        NSString* stdOut = nil;
        NSArray* cmdArgv = @[dpkgPath, @"-i", getRootFSPath(debPath)];
        int ret = spawn(cmdArgv, &stdOut, 0);
        NSLog(@"%@ instDeb spawn %@ -> %d", log_prefix, [cmdArgv componentsJoinedByString:@" "], ret);
        fileLog(log_path, @"%@ spawn %@ -> %d\n", getDateTime(), [cmdArgv componentsJoinedByString:@" "], ret);
        if (stdOut != nil) {
            NSLog(@"%@ instDeb %@", log_prefix, fmt1Line(stdOut));
            fileLog(log_path, @"%@\n", stdOut);
        }
        return ret;
    }
}

static int instIpa(NSString* tipaPath, NSString* __strong* err) {
    @autoreleasepool {
        NSString* helperPath = getTrollStoreHelper();
        if (helperPath == nil) {
            *err = @"instIpa: could not find helper";
            return -1;
        }
        NSString* stdOut = nil;
        NSArray* cmdArgv = @[helperPath, @"install", @"force", getRootFSPath(tipaPath)];
        int ret = spawn(cmdArgv, &stdOut, 0);
        NSLog(@"%@ instIpa spawn %@ -> %d", log_prefix, [cmdArgv componentsJoinedByString:@" "], ret);
        fileLog(log_path, @"%@ spawn %@ -> %d\n", getDateTime(), [cmdArgv componentsJoinedByString:@" "], ret);
        if (stdOut != nil) {
            NSLog(@"%@ instIpa %@", log_prefix, fmt1Line(stdOut));
            fileLog(log_path, @"%@\n", stdOut);
        }
        return ret;
    }
}

static NSDictionary* instPkg(NSString* pkgPath, NSString* __strong* err) {
    @autoreleasepool {
        NSString* bundlePath = getAppBundleFromPkg(pkgPath, err);
        if (bundlePath == nil) {
            return nil;
        }
        NSDictionary* infoDic = getAppInfoFromPkg(pkgPath, err);
        NSString* appBid = infoDic[@"CFBundleIdentifier"];
        if (appBid == nil) {
            *err = @"instPkg: appBid nil";
            return nil;
        }
        int pkg_type = getPkgType(infoDic[@"jbdev"]);
        if (pkg_type == PKG_TYPE_JAILBREAK) {
            NSString* debPath = [bundlePath stringByAppendingPathComponent:@"payload.deb"];
            if ([NSFileManager.defaultManager fileExistsAtPath:debPath]) {
                if (0 != instDeb(debPath, err)) {
                    return nil;
                }
            }
        } else if (pkg_type == PKG_TYPE_TROLLSTORE) {
            NSString* tipaPath = [bundlePath stringByAppendingPathComponent:@"payload.tipa"];
            if ([NSFileManager.defaultManager fileExistsAtPath:tipaPath]) {
                if (0 != instIpa(tipaPath, err)) {
                    return nil;
                }
            }
        }
        if (!isAppInstalled(appBid)) {
            *err = [NSString stringWithFormat:@"app not installed %@", appBid];
            return nil;
        }
        return getAppInfo(appBid);
    }
}

static void init_env() {
    @autoreleasepool {
#if defined(THEOS_PACKAGE_SCHEME_ROOTLESS) || defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        NSArray* binPathArr = @[
            @"/bin",
            @"/sbin",
            @"/usr/bin",
            @"/usr/sbin", 
            @"/usr/local/bin", 
            @"/usr/local/sbin",
            @(JBROOT("/bin")),
            @(JBROOT("/sbin")),
            @(JBROOT("/usr/bin")),
            @(JBROOT("/usr/sbin")),
            @(JBROOT("/usr/local/bin")), 
            @(JBROOT("/usr/local/sbin")),
        ];
        NSString* pathAll = [binPathArr componentsJoinedByString:@":"];
        setenv("PATH", pathAll.UTF8String, 1);
#endif
    }
}

int main(int argc, char** argv) {
    init_env();
    fileLog(log_path, @"%@ JBDev start\n", getDateTime());
    setIPCHandler(@"jbdev.req.info_pkg", ^(NSString* name, NSDictionary* info) {
        @autoreleasepool {
            NSString* pkgPath = info[@"pkg_path"];
            NSString* err = nil;
            NSDictionary* infoDic = getAppInfoFromPkg(pkgPath, &err);
            if (infoDic == nil) {
                NSLog(@"%@ info_pkg %@ err: %@", log_prefix, pkgPath, err);
                fileLog(log_path, @"%@ info_pkg %@ err: %@\n", getDateTime(), pkgPath, err);
                sendIPC(@"jbdev.res.info_pkg", @{
                    @"status": @-1
                });
            } else {
                NSDictionary* jbdevDic = infoDic[@"jbdev"];
                NSLog(@"%@ info_pkg %@ pkgType: %@", log_prefix, pkgPath, jbdevDic[@"type"]);
                fileLog(log_path, @"%@ info_pkg %@ pkgType: %@\n", getDateTime(), pkgPath, jbdevDic[@"type"]);
                sendIPC(@"jbdev.res.info_pkg", @{
                    @"status": @0,
                    @"data": infoDic,
                });
            }
        }
    });
    setIPCHandler(@"jbdev.req.inst_pkg", ^(NSString* name, NSDictionary* info) {
        @autoreleasepool {
            NSString* pkgPath = info[@"pkg_path"];
            NSString* err = nil;
            NSDictionary* appInfo = instPkg(pkgPath, &err);
            if (appInfo == nil) {
                NSLog(@"%@ inst_pkg %@ err: %@", log_prefix, pkgPath, err);
                fileLog(log_path, @"%@ inst_pkg %@ err: %@\n", getDateTime(), pkgPath, err);
                sendIPC(@"jbdev.res.inst_pkg", @{
                    @"status": @-2
                });
            } else {
                NSLog(@"%@ inst_pkg %@ suc", log_prefix, pkgPath);
                fileLog(log_path, @"%@ inst_pkg %@ suc\n", getDateTime(), pkgPath);
                sendIPC(@"jbdev.res.inst_pkg", @{
                    @"status": @0,
                    @"data": appInfo
                });
            }
        }
    });
    CFRunLoopRun();
    return 0;
}

