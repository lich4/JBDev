#import <Foundation/Foundation.h>

static __attribute__((constructor)) void Ctor() {
    NSLog(@"JBDevTestTweak enter %@", NSBundle.mainBundle.bundleIdentifier);
}
