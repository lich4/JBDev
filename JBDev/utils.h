#ifndef utils_h
#define utils_h

#import <Foundation/Foundation.h>

typedef void(^IPCHandler)(NSString* name, NSDictionary* info);
void setIPCHandler(NSString* name, IPCHandler handler);
void sendIPC(NSString* name, NSDictionary* info);

NSString* getDateTime(int64_t second=0, NSString* fmt=nil);
void fileLog(NSString* path, NSString* fmt, ...);
NSString* fmt1Line(NSString* fmt, ...);

NSString* getTrollStoreHelper();

enum {
    SPAWN_FLAG_ROOT     = 1,
    SPAWN_FLAG_NOWAIT   = 2,
};
int spawn(NSArray* args, NSString** stdOut, int flag);

#endif // utils_h
