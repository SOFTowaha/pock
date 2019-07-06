//
//  PockDockHelper.m
//  Pock
//
//  Created by Pierluigi Galdi on 01/08/18.
//  Copyright © 2018 Pierluigi Galdi. All rights reserved.
//

#import "PockDockHelper.h"

#define kAXStatusLabelAttribute CFSTR("AXStatusLabel")

void SafeCFRelease(CFTypeRef cf) {
    if (cf) CFRelease(cf);
}

@implementation PockDockHelper

+ (PockDockHelper *)sharedInstance {
    static PockDockHelper *sharedInstance = nil;
    @synchronized(self) {
        if (sharedInstance == nil)
            sharedInstance = [[self alloc] init];
    }
    return sharedInstance;
}

//  Thanks to: @Minebomber
//  Ref:       https://stackoverflow.com/a/36115210
//
- (AXUIElementRef)copyAXUIElementFrom:(AXUIElementRef)theContainer role:(CFStringRef)theRole atIndex:(NSInteger)theIndex {
    AXUIElementRef aResultElement = NULL;
    CFTypeRef aChildren;
    AXError anAXError = AXUIElementCopyAttributeValue(theContainer, kAXChildrenAttribute, &aChildren);
    if (anAXError == kAXErrorSuccess) {
        NSUInteger anIndex = -1;
        for (id anElement in (__bridge NSArray *)aChildren) {
            if (theRole) {
                CFTypeRef aRole;
                anAXError = AXUIElementCopyAttributeValue((__bridge AXUIElementRef)anElement, kAXRoleAttribute, &aRole);
                if (anAXError == kAXErrorSuccess) {
                    if (CFStringCompare(aRole, theRole, 0) == kCFCompareEqualTo)
                        anIndex++;
                    SafeCFRelease(aRole);
                }
            }
            else
                anIndex++;
            if (anIndex == theIndex) {
                aResultElement = (AXUIElementRef)CFRetain((__bridge CFTypeRef)(anElement));
                break;
            }
        }
        SafeCFRelease(aChildren);
    }
    return aResultElement;
}

//  Thanks to: @Minebomber
//  Ref:       https://stackoverflow.com/a/36115210
//
- (AXUIElementRef)getDockItemWithName:(NSString *)name {
    NSArray *anArray = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.dock"];
    if (anArray.count == 0) return nil;
    AXUIElementRef anAXDockApp = AXUIElementCreateApplication([[anArray objectAtIndex:0] processIdentifier]);
    AXUIElementRef aList = [self copyAXUIElementFrom:anAXDockApp role:kAXListRole atIndex:0];
    if (aList == nil) return nil;
    CFTypeRef aChildren;
    AXUIElementCopyAttributeValue(aList, kAXChildrenAttribute, &aChildren);
    NSInteger itemIndex = -1;
    if (aChildren == nil) return nil;
    for (NSInteger i = 0; i < CFArrayGetCount(aChildren); i++) {
        AXUIElementRef anElement = CFArrayGetValueAtIndex(aChildren, i);
        CFTypeRef aResult;
        AXUIElementCopyAttributeValue(anElement, kAXTitleAttribute, &aResult);
        if ([(__bridge NSString *)aResult isEqualToString:name]) {
            itemIndex = i;
        }
        SafeCFRelease(aResult);
    }
    SafeCFRelease(aChildren);
    SafeCFRelease(anAXDockApp);
    if (itemIndex == -1) {
        SafeCFRelease(aList);
        return nil;
    }
    AXUIElementRef aReturnItem = [self copyAXUIElementFrom:aList role:kAXDockItemRole atIndex:itemIndex];
    if (aReturnItem == nil) {
        SafeCFRelease(aList);
        return nil;
    }
    SafeCFRelease(aList);
    return  aReturnItem;
}

- (NSString *)getBadgeCountForItemWithName:(NSString *)name {
    AXUIElementRef dockItem = [self getDockItemWithName:name];
    if (dockItem == nil) return nil;
    CFTypeRef aStatusLabel;
    AXUIElementCopyAttributeValue(dockItem, kAXStatusLabelAttribute, &aStatusLabel);
    SafeCFRelease(dockItem);
    NSString *statusLabel = (__bridge NSString *)aStatusLabel;
    SafeCFRelease(aStatusLabel);
    return statusLabel;
}

- (CFArrayRef)getWindowsOfAppWithPid:(pid_t)pid {
    if (pid <= 0) { return nil; }
    AXUIElementRef elementRef = AXUIElementCreateApplication(pid);
    CFArrayRef windowArray = nil;
    AXUIElementCopyAttributeValue(elementRef, kAXWindowsAttribute, (CFTypeRef*)&windowArray);
    SafeCFRelease(elementRef);
    if (windowArray == nil) {
        return nil;
    }
    CFIndex nItems = CFArrayGetCount(windowArray);
    if (nItems < 1) {
        SafeCFRelease(windowArray);
        return nil;
    }
    return windowArray;
}

- (NSUInteger)windowsCountForApp:(NSRunningApplication *)app {
    CFArrayRef array = [self getWindowsOfAppWithPid:app.processIdentifier];
    if (array == nil) { return 0; }
    NSArray *arr = (NSArray *)CFBridgingRelease(array);
//  CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
//  NSArray *_arr = (NSArray *)CFBridgingRelease(windowList);
//  return _arr.count;
    return arr.count;
}

- (NSString *)getTitleForElement:(AXUIElementRef)element {
    AXUIElementRef title = nil;
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute, (CFTypeRef*)&title);
    return (NSString *)CFBridgingRelease(title);
}

- (void)closeWindowAtPosition:(int)position forApp:(NSRunningApplication *)app {
    CFArrayRef windows = [self getWindowsOfAppWithPid:app.processIdentifier];
    AXUIElementRef itemRef = (AXUIElementRef) CFArrayGetValueAtIndex(windows, position);
    AXUIElementRef buttonRef = nil;
    AXUIElementCopyAttributeValue(itemRef, kAXCloseButtonAttribute, (CFTypeRef*)&buttonRef);
    AXUIElementPerformAction(buttonRef, kAXPressAction);
    SafeCFRelease(buttonRef);
    SafeCFRelease(itemRef);
}

- (void)activateWindowAtPosition:(int)position forApp:(NSRunningApplication *)app {
    CFArrayRef windows = [self getWindowsOfAppWithPid:app.processIdentifier];
    AXUIElementRef itemRef = (AXUIElementRef)CFArrayGetValueAtIndex(windows, position);
    AXUIElementPerformAction(itemRef, kAXRaiseAction);
    [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    AXUIElementSetAttributeValue(itemRef, kAXMainWindowAttribute, kCFBooleanTrue);
    SafeCFRelease(itemRef);
}

@end
