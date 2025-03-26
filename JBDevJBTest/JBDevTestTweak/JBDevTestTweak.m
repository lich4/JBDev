//
//  JBDevTestTweak.m
//  JBDevTestTweak
//
//  Created by apple on 2025/3/19.
//

#import <Foundation/Foundation.h>
#include <CydiaSubstrate/CydiaSubstrate.h>

#if defined(THEOS_PACKAGE_SCHEME_ROOTLESS)
#include <rootless.h>
#define JBROOT(X)   "/var/jb" X
#elif defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
#include <roothide.h>
#define JBROOT(X)   jbroot(X)
#else
#define JBROOT(X)   X
#endif

__attribute__((constructor)) static void ctor() {
    NSLog(@"JBDev TestTweak load root=%s", JBROOT("/"));
    NSLog(@"JBDev TestTweak load fp=%p", (void*)MSHookFunction);
}

