#include "utils.h"
#include <spawn.h>

extern "C" {
CFNotificationCenterRef CFNotificationCenterGetDistributedCenter();
}

void setIPCHandler(NSString* name, IPCHandler handler) {
    @autoreleasepool {
        static NSMutableDictionary* g_handlers = [NSMutableDictionary new];
        if (g_handlers[name] == nil) {
            g_handlers[name] = handler;
            CFNotificationCenterRef center = CFNotificationCenterGetDistributedCenter();
            CFNotificationCenterAddObserver(center, NULL, [](CFNotificationCenterRef, void*, CFStringRef nameRef, void const*, CFDictionaryRef infoRef) {
                @autoreleasepool {
                    NSString* name = (__bridge NSString*)nameRef;
                    IPCHandler handler = g_handlers[name];
                    if (handler != nil) {
                        NSDictionary* info = (__bridge NSDictionary*)infoRef;
                        handler(name, info);
                    }
                }
            }, (__bridge CFStringRef)name, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        } else {
            g_handlers[name] = handler;
        }
    }
}

void sendIPC(NSString* name, NSDictionary* info) {
    CFNotificationCenterRef center = CFNotificationCenterGetDistributedCenter();
    CFNotificationCenterPostNotification(center, (__bridge CFStringRef)name, NULL, (__bridge CFDictionaryRef)info, YES);
}


NSString* getDateTime(int64_t second, NSString* fmt) {
    @autoreleasepool {
        if (second == 0) {
            second = (int)[[NSDate date] timeIntervalSince1970];
        }
        NSDate* date = [NSDate dateWithTimeIntervalSince1970:second];
        NSDateFormatter* formatter = [NSDateFormatter new];
        NSString* format = @"";
        if (fmt == nil) { // YMDhms
            format = @"YYYY-MM-dd HH:mm:ss";
        } else {
            if ([fmt rangeOfString:@"Y"].location != NSNotFound) {
                format = [format stringByAppendingString:@"YYYY"];
            }
            if ([fmt rangeOfString:@"M"].location != NSNotFound) {
                if (format.length != 0) {
                    format = [format stringByAppendingString:@"-"];
                }
                format = [format stringByAppendingString:@"MM"];
            }
            if ([fmt rangeOfString:@"D"].location != NSNotFound) {
                if (format.length != 0) {
                    format = [format stringByAppendingString:@"-"];
                }
                format = [format stringByAppendingString:@"dd"];
            }
            if ([fmt rangeOfString:@"h"].location != NSNotFound) {
                if (format.length != 0) {
                    format = [format stringByAppendingString:@" "];
                }
                format = [format stringByAppendingString:@"HH"];
            }
            if ([fmt rangeOfString:@"m"].location != NSNotFound) {
                if (format.length != 0) {
                    format = [format stringByAppendingString:@":"];
                }
                format = [format stringByAppendingString:@"mm"];
            }
            if ([fmt rangeOfString:@"s"].location != NSNotFound) {
                if (format.length != 0) {
                    format = [format stringByAppendingString:@":"];
                }
                format = [format stringByAppendingString:@"ss"];
            }
        }
        [formatter setDateFormat:format];
        return [formatter stringFromDate:date];
    }
}

void fileLog(NSString* path, NSString* fmt, ...) {
    @autoreleasepool {
        va_list va;
        va_start(va, fmt);
        NSString* content = [[NSString alloc] initWithFormat:fmt arguments:va];
        va_end(va);
        NSFileHandle* handle = nil;
        if ([path isEqualToString:@"stdout"]) {
            handle = [NSFileHandle fileHandleWithStandardOutput];
        } else {
            handle = [NSFileHandle fileHandleForWritingAtPath:path];
            if (handle == nil) {
                [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
                handle = [NSFileHandle fileHandleForWritingAtPath:path];
            }
        }
        if (handle != nil) {
            [handle seekToEndOfFile];
            [handle writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
            [handle closeFile];
        }
    }
}

NSString* fmt1Line(NSString* fmt, ...) {
    @autoreleasepool {
        va_list va;
        va_start(va, fmt);
        NSString* content = [[NSString alloc] initWithFormat:fmt arguments:va];
        va_end(va);
        content = [content stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        return content;
    }
}

NSString* getTrollStoreHelper() {
    NSString* trollStoreBundlePath = nil;
    NSString* appContainersPath = @"/var/containers/Bundle/Application";
    NSError* error;
    NSArray* containers = [NSFileManager.defaultManager contentsOfDirectoryAtPath:appContainersPath error:&error];
    for(NSString* container in containers) {
        NSString* containerPath = [appContainersPath stringByAppendingPathComponent:container];
        NSString* trollStoreApp = [containerPath stringByAppendingPathComponent:@"TrollStore.app"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:trollStoreApp]) {
            trollStoreBundlePath = trollStoreApp;
            break;
        }
    }
    if (trollStoreBundlePath == nil) {
        return nil;
    }
    NSString* helperPath = [trollStoreBundlePath stringByAppendingPathComponent:@"trollstorehelper"];
    if (![NSFileManager.defaultManager fileExistsAtPath:helperPath]) {
        return nil;
    }
    return helperPath;
}


#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1

extern "C" {
int posix_spawnattr_set_persona_np(const posix_spawnattr_t*, uid_t, uint32_t);
int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t*, uid_t);
int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t*, uid_t);
}
extern char** environ;

static void readPipeToString(int fd, NSMutableString* ms) {
    if (fcntl(fd, F_GETFD) == -1 && errno == EBADF) {
        return;
    }
    ssize_t num_read = 0;
    char c = 0;
    while ((num_read = read(fd, &c, sizeof(c))) > 0) {
        [ms appendString:[NSString stringWithFormat:@"%c", c]];
    }
}

int spawn(NSArray* args, NSString** stdOut, int flag) {
    NSString* file = args.firstObject;
    NSUInteger argCount = [args count];
    const char** argsC = (const char**)malloc((argCount + 1) * sizeof(char*));
    for (NSUInteger i = 0; i < argCount; i++) {
        argsC[i] = [args[i] UTF8String];
    }
    argsC[argCount] = NULL;
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    if ((flag & SPAWN_FLAG_ROOT) != 0) {
        posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
        posix_spawnattr_set_persona_uid_np(&attr, 0);
        posix_spawnattr_set_persona_gid_np(&attr, 0);
    }
    posix_spawn_file_actions_t action;
    posix_spawn_file_actions_init(&action);
    BOOL outEnabled = stdOut != nil;
    int outOut[2], outErr[2];
    if (outEnabled) {
        pipe(outOut);
        posix_spawn_file_actions_adddup2(&action, outOut[1], STDOUT_FILENO);
        posix_spawn_file_actions_addclose(&action, outOut[0]);
        pipe(outErr);
        posix_spawn_file_actions_adddup2(&action, outErr[1], STDERR_FILENO);
        posix_spawn_file_actions_addclose(&action, outErr[0]);
    }
    pid_t task_pid = -1;
    int err_spawn = posix_spawn(&task_pid, file.UTF8String, &action, &attr, (char* const*)argsC, environ);
    posix_spawnattr_destroy(&attr);
    free(argsC);
    if (err_spawn != 0) {
        return -0x100 - err_spawn;
    }
    if ((flag & SPAWN_FLAG_NOWAIT) != 0) {
        return 0;
    }
    NSMutableString* outString = [NSMutableString new];
    NSMutableString* errString = [NSMutableString new];
    __block volatile BOOL _isRunning = YES;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    if (outEnabled) {
        dispatch_queue_t logQueue = dispatch_queue_create("jbdev", nil);
        int outOutPipe = outOut[0];
        int outErrPipe = outErr[0];
        dispatch_async(logQueue, ^{
            while (_isRunning) {
                @autoreleasepool {
                    readPipeToString(outOutPipe, outString);
                    readPipeToString(outErrPipe, errString);
                }
            }
            dispatch_semaphore_signal(sema);
        });
    }
    int status = 0;
    do {
        if (waitpid(task_pid, &status, 0) == -1) {
            _isRunning = NO;
            if (outEnabled) {
                close(outOut[1]);
                close(outErr[1]);
            }
            return -0x200 - errno;
        }
    } while (!WIFEXITED(status) && !WIFSIGNALED(status));
    _isRunning = NO;
    if (outEnabled) {
        close(outOut[1]);
        close(outErr[1]);
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        *stdOut = [NSString stringWithFormat:@"%@\n%@\n", outString, errString];
    }
    return WEXITSTATUS(status);
}

