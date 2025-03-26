//
//  main.m
//  JBDevTest
//
//  Created by apple on 2025/3/19.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    setuid(0);
    setgid(0);
    NSLog(@"JBDevTest uid=%d gid=%d", getuid(), getgid());
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}

