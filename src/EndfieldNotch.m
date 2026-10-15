/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Yixuan Zhang
 */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <crt_externs.h>
#include <stdio.h>
#include <string.h>
#include "geometry.h"
#import "endfield_coords.h"

static void (*original_frame)(id, SEL, NSRect);
static void (*original_fullscreen)(id, SEL);
static void (*original_post_frame)(id, SEL, NSRect, BOOL, BOOL, BOOL);
static void (*original_mouse_button)(id, SEL, NSEvent *);
static char active_key, screen_key, logical_key, physical_key;
static NSMapTable<NSWindow *, NSWindow *> *bars;
static BOOL owns_presentation, updating_presentation;
static NSApplicationPresentationOptions saved_presentation;

@protocol EFClipReading
- (BOOL)clippingCursor;
- (CGRect)cursorClipRect;
@end
@protocol EFDrawableReading
- (CGSize)drawableSize;
@end

static CGSize find_drawable_size(NSView *view, unsigned depth)
{
    if (!view || depth > 10) return CGSizeZero;
    id layer = view.layer;
    if ([layer respondsToSelector:@selector(drawableSize)])
        return [(id<EFDrawableReading>)layer drawableSize];
    for (NSView *child in view.subviews) {
        CGSize size = find_drawable_size(child, depth + 1);
        if (size.width && size.height) return size;
    }
    return CGSizeZero;
}

@interface EFBlackStripView : NSView
@end
@implementation EFBlackStripView
- (BOOL)isOpaque { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { (void)event; return YES; }
- (void)drawRect:(NSRect)rect { [NSColor.blackColor setFill]; NSRectFill(rect); }
- (void)mouseDown:(NSEvent *)event { (void)event; }
- (void)mouseUp:(NSEvent *)event { (void)event; }
- (void)rightMouseDown:(NSEvent *)event { (void)event; }
- (void)rightMouseUp:(NSEvent *)event { (void)event; }
- (void)otherMouseDown:(NSEvent *)event { (void)event; }
- (void)otherMouseUp:(NSEvent *)event { (void)event; }
- (void)mouseDragged:(NSEvent *)event { (void)event; }
- (void)rightMouseDragged:(NSEvent *)event { (void)event; }
- (void)otherMouseDragged:(NSEvent *)event { (void)event; }
- (void)scrollWheel:(NSEvent *)event { (void)event; }
@end

@interface EFNotchBar : NSPanel
@end
@implementation EFNotchBar
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

static BOOL is_enabled(NSWindow *window)
{
    return [objc_getAssociatedObject(window, &active_key) boolValue];
}

static CGPoint map_window_point(NSWindow *window, CGPoint point, BOOL inverse)
{
    if (!is_enabled(window)) return point;
    CGRect physical = [objc_getAssociatedObject(window, &physical_key) rectValue];
    CGRect logical = [objc_getAssociatedObject(window, &logical_key) rectValue];
    return inverse ? ef_map_point(point, logical, physical) : ef_map_point(point, physical, logical);
}

static CGPoint logical_point(id window, SEL selector, CGPoint point)
{
    (void)selector;
    return map_window_point(window, point, NO);
}

static CGPoint physical_point(id window, SEL selector, CGPoint point)
{
    (void)selector;
    return map_window_point(window, point, YES);
}

static CGRect logical_rect(id window, SEL selector, CGRect rect)
{
    (void)selector;
    CGPoint a = map_window_point(window, rect.origin, NO);
    CGPoint b = map_window_point(window, CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)), NO);
    return CGRectMake(a.x, a.y, b.x - a.x, b.y - a.y);
}

static void diagnose_mouse_button(id controller, SEL selector, NSEvent *event)
{
    NSWindow *window = event.window;
    static unsigned clicks;
    if (is_enabled(window) && event.type == NSEventTypeLeftMouseDown && clicks++ < 80) {
        CGPoint physical = CGEventGetLocation(event.CGEvent);
        CGPoint logical = map_window_point(window, physical, NO);
        NSRect content = [window contentRectForFrameRect:window.frame];
        NSSize bounds = window.contentView.bounds.size;
        CGSize drawable = find_drawable_size(window.contentView, 0);
        BOOL clipping = NO;
        CGRect clip = CGRectZero;
        @try {
            id<EFClipReading> handler = [controller valueForKey:@"clipCursorHandler"];
            clipping = handler.clippingCursor;
            clip = handler.cursorClipRect;
        } @catch (NSException *exception) { (void)exception; }
        fprintf(stderr, "[EndfieldPointer] physical=(%.1f,%.1f) logical=(%.1f,%.1f) local=(%.1f,%.1f) contentCocoa=(%.1f,%.1f %.1fx%.1f) bounds=(%.1f,%.1f) drawable=(%.0f,%.0f) scale=%.1f clipActive=%d clip=(%.1f,%.1f %.1fx%.1f) style=%lu\n",
                physical.x, physical.y, logical.x, logical.y, event.locationInWindow.x, event.locationInWindow.y,
                content.origin.x, content.origin.y, content.size.width, content.size.height,
                bounds.width, bounds.height, drawable.width, drawable.height,
                window.backingScaleFactor, clipping, clip.origin.x, clip.origin.y,
                clip.size.width, clip.size.height, (unsigned long)window.styleMask);
    }
    original_mouse_button(controller, selector, event);
}

static BOOL should_cover(NSWindow *window)
{
    return is_enabled(window) && window.visible && !window.miniaturized &&
           window.onActiveSpace && NSApp.active && !NSApp.hidden;
}

static void update_presentation(void)
{
    if (updating_presentation) return;
    updating_presentation = YES;
    BOOL hide = NO;
    for (NSWindow *window in bars.keyEnumerator)
        if (should_cover(window)) { hide = YES; break; }
    const NSApplicationPresentationOptions owned =
        NSApplicationPresentationHideMenuBar | NSApplicationPresentationAutoHideMenuBar |
        NSApplicationPresentationHideDock | NSApplicationPresentationAutoHideDock |
        NSApplicationPresentationAutoHideToolbar;
    @try {
        if (hide) {
            if (!owns_presentation) saved_presentation = NSApp.presentationOptions;
            NSApplicationPresentationOptions desired =
                (NSApp.presentationOptions & ~owned) |
                NSApplicationPresentationHideMenuBar | NSApplicationPresentationHideDock;
            if (NSApp.presentationOptions != desired) NSApp.presentationOptions = desired;
            if (!owns_presentation)
                fprintf(stderr, "[EndfieldNotch] menu bar and Dock hidden/disabled for active fullscreen; app switching retained\n");
            owns_presentation = YES;
        } else if (owns_presentation) {
            NSApp.presentationOptions = (NSApp.presentationOptions & ~owned) | (saved_presentation & owned);
            owns_presentation = NO;
            fprintf(stderr, "[EndfieldNotch] previous menu bar/Dock presentation restored\n");
        }
    } @catch (NSException *exception) {
        fprintf(stderr, "[EndfieldNotch] presentation update failed: %s\n", exception.reason.UTF8String);
    }
    updating_presentation = NO;
}

static void safe_post_frame(id object, SEL selector, NSRect frame, BOOL fullscreen,
                            BOOL resizing, BOOL skip_size_move)
{
    BOOL active = is_enabled(object);
    if (active) {
        /* Keep Unity's client dimensions consistent with its swap chain.
           Only Cocoa sees the smaller safe-area rectangle. This method's
           argument is bottom-up, unlike the stored Win32 request. */
        frame = [objc_getAssociatedObject(object, &logical_key) rectValue];
        NSArray<NSScreen *> *screens = NSScreen.screens;
        CGFloat top = screens.count ? NSMaxY(screens[0].frame) : 0;
        frame.origin.y = top - NSMaxY(frame);
    }
    original_post_frame(object, selector, frame, fullscreen || active, resizing,
                        skip_size_move || active);
    if (active) {
        static NSRect last;
        if (!NSEqualRects(last, frame)) {
            last = frame;
            fprintf(stderr, "[EndfieldNotch] logical Win32 frame notification Cocoa=(%.1f,%.1f %.1fx%.1f) fullscreen=1 no-changing=1\n",
                    frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);
        }
    }
}

static void update_bar(NSWindow *window)
{
    NSWindow *bar = [bars objectForKey:window];
    NSScreen *screen = objc_getAssociatedObject(window, &screen_key);
    if (!screen || !should_cover(window))
    {
        [bar orderOut:nil];
        update_presentation();
        return;
    }
    CGFloat inset = screen.safeAreaInsets.top;
    if (inset <= 0) { [bar orderOut:nil]; update_presentation(); return; }
    if (!bar)
    {
        bar = [[EFNotchBar alloc] initWithContentRect:NSZeroRect
                    styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered defer:NO];
        bar.backgroundColor = NSColor.blackColor;
        bar.opaque = YES;
        bar.hasShadow = NO;
        bar.contentView = [[EFBlackStripView alloc] initWithFrame:NSZeroRect];
        bar.ignoresMouseEvents = NO;
        bar.hidesOnDeactivate = YES;
        ((NSPanel *)bar).becomesKeyOnlyIfNeeded = YES;
        bar.collectionBehavior = NSWindowCollectionBehaviorFullScreenAuxiliary |
                                 NSWindowCollectionBehaviorIgnoresCycle;
        [bars setObject:bar forKey:window];
    }
    NSRect rect = screen.frame;
    rect.origin.y = NSMaxY(rect) - inset;
    rect.size.height = inset;
    [bar setFrame:rect display:YES];
    /* An independent panel keeps its level above the system menu bar. A child
       panel ordered below the Wine window can get pushed back under the menu. */
    bar.level = MAX(window.level + 1, NSPopUpMenuWindowLevel + 1);
    [bar orderFrontRegardless];
    update_presentation();
}

static void safe_update_fullscreen(id object, SEL selector)
{
    original_fullscreen(object, selector);
    NSWindow *window = object;
    if (is_enabled(window))
    {
        SEL getter = sel_registerName("fullscreen");
        SEL setter = sel_registerName("setFullscreen:");
        if (![window respondsToSelector:getter] || ![window respondsToSelector:setter]) return;
        if (!((BOOL (*)(id, SEL))objc_msgSend)(window, getter))
        {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(window, setter, YES);
            Class cls = NSClassFromString(@"WineApplicationController");
            id controller = ((id (*)(id, SEL))objc_msgSend)(cls, sel_registerName("sharedController"));
            ((void (*)(id, SEL))objc_msgSend)(controller, sel_registerName("updateFullscreenWindows"));
            ((void (*)(id, SEL))objc_msgSend)(controller, sel_registerName("adjustWindowLevels"));
        }
    }
    update_bar(window);
}

static void safe_set_frame(id object, SEL selector, NSRect requested)
{
    NSWindow *window = object;
    NSRect adjusted = requested;
    NSScreen *matched = nil;
    NSArray<NSScreen *> *screens = NSScreen.screens;
    CGFloat primary_top = screens.count ? NSMaxY(screens[0].frame) : 0;
    BOOL decorated = (window.styleMask & (NSWindowStyleMaskTitled | NSWindowStyleMaskFullScreen)) != 0;
    for (NSScreen *screen in screens)
    {
        NSRect frame = screen.frame;
        frame.origin.y = primary_top - NSMaxY(frame);
        CGRect safe;
        if (ef_safe_frame(NSRectToCGRect(requested), NSRectToCGRect(frame),
                          screen.safeAreaInsets.top, decorated, &safe))
        {
            adjusted = NSRectFromCGRect(safe);
            matched = screen;
            break;
        }
    }
    BOOL previous = is_enabled(window);
    static int unmatched_logs;
    if (!matched && requested.size.width > 1000 && requested.size.height > 600 && unmatched_logs++ < 8)
        fprintf(stderr, "[EndfieldNotch] unclamped request=(%.1f,%.1f %.1fx%.1f) decorated=%d screens=%lu firstInset=%.1f\n",
                requested.origin.x, requested.origin.y, requested.size.width, requested.size.height,
                decorated, (unsigned long)screens.count, screens.count ? screens[0].safeAreaInsets.top : 0);
    objc_setAssociatedObject(window, &active_key, @(matched != nil), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(window, &screen_key, matched, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(window, &logical_key, matched ? [NSValue valueWithRect:requested] : nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(window, &physical_key, matched ? [NSValue valueWithRect:adjusted] : nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (matched && (!previous || !NSEqualRects(requested, adjusted)))
        fprintf(stderr, "[EndfieldNotch] requested=(%.1f,%.1f %.1fx%.1f) safe=(%.1f,%.1f %.1fx%.1f) top=%.1f points\n",
                requested.origin.x, requested.origin.y, requested.size.width, requested.size.height,
                adjusted.origin.x, adjusted.origin.y, adjusted.size.width, adjusted.size.height,
                matched.safeAreaInsets.top);
    if (previous && !matched) fprintf(stderr, "[EndfieldNotch] ordinary window: safe-area clamp disabled\n");
    /* Keep the Win32 request intact. The driver bridge converts input after
       physical hit testing and before Retina scaling, with an inverse for
       cursor warps and clipping. */
    original_frame(object, selector, adjusted);
    /* Wine's client-surface subviews retain Win32 dimensions. Scale their
       common parent coordinate system, so a 1964-pixel Metal view fits the
       1900-pixel safe viewport instead of being cropped at the bottom. */
    if (matched)
        [window.contentView setBoundsSize:requested.size];
    else if (previous)
        [window.contentView setBoundsSize:window.contentView.frame.size];
    if (matched)
    {
        /* setFrameFromWine discards older pending frame events. When the
           native frame is already clamped it skips the usual resize callback,
           even if the game's Win32 request has reset its virtual geometry. */
        ((void (*)(id, SEL, id, BOOL))objc_msgSend)(window,
            sel_registerName("windowDidResize:skipSizeMove:"), nil, YES);
    }
    update_bar(window);
}

static void install_hooks(void)
{
    Class cls = NSClassFromString(@"WineWindow");
    Method frame = class_getInstanceMethod(cls, sel_registerName("setFrameFromWine:"));
    Method full = class_getInstanceMethod(cls, sel_registerName("updateFullscreen"));
    Method post = class_getInstanceMethod(cls, sel_registerName("postWindowFrameChanged:fullscreen:resizing:skipSizeMove:"));
    if (!frame || !full || !post)
    {
        static int attempts;
        if (attempts++ < 200) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ install_hooks(); });
            return;
        }
        fprintf(stderr, "[EndfieldNotch] required WineWindow methods unavailable; no hooks installed\n");
        return;
    }
    Class controller = NSClassFromString(@"WineApplicationController");
    if (!class_getInstanceMethod(controller, sel_registerName("efNotchCoordinateBridgeVersion"))) {
        fprintf(stderr, "[EndfieldNotch] v4 requires coordinate-aware winemac; hooks inactive\n");
        return;
    }
    SEL selectors[] = {@selector(efNotchLogicalPointForPhysicalPoint:),
                       @selector(efNotchPhysicalPointForLogicalPoint:),
                       @selector(efNotchLogicalRectForPhysicalRect:)};
    IMP implementations[] = {(IMP)logical_point, (IMP)physical_point, (IMP)logical_rect};
    for (unsigned i = 0; i < 3; i++) {
        struct objc_method_description method = protocol_getMethodDescription(@protocol(EFNotchCoordinates),
                                                                               selectors[i], YES, YES);
        if (!method.types || !class_addMethod(cls, selectors[i], implementations[i], method.types)) {
            fprintf(stderr, "[EndfieldNotch] coordinate bridge installation failed; hooks inactive\n");
            return;
        }
    }
    bars = [NSMapTable weakToStrongObjectsMapTable];
    original_frame = (void *)method_setImplementation(frame, (IMP)safe_set_frame);
    original_fullscreen = (void *)method_setImplementation(full, (IMP)safe_update_fullscreen);
    original_post_frame = (void *)method_setImplementation(post, (IMP)safe_post_frame);
    Method mouse = class_getInstanceMethod(NSClassFromString(@"WineApplicationController"), sel_registerName("handleMouseButton:"));
    if (mouse) original_mouse_button = (void *)method_setImplementation(mouse, (IMP)diagnose_mouse_button);
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (NSNotificationName name in @[NSWindowDidBecomeKeyNotification, NSWindowDidResizeNotification,
                                      NSWindowDidMoveNotification, NSWindowDidMiniaturizeNotification,
                                      NSWindowDidDeminiaturizeNotification, NSWindowDidChangeOcclusionStateNotification])
        [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if ([note.object isKindOfClass:cls]) update_bar(note.object);
        }];
    for (NSNotificationName name in @[NSApplicationDidBecomeActiveNotification, NSApplicationDidResignActiveNotification,
                                      NSApplicationDidHideNotification, NSApplicationDidUnhideNotification])
        [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            (void)note;
            for (NSWindow *window in bars.keyEnumerator) update_bar(window);
            update_presentation();
        }];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserverForName:NSWorkspaceActiveSpaceDidChangeNotification
         object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        (void)note;
        for (NSWindow *window in bars.keyEnumerator) update_bar(window);
        update_presentation();
    }];
    [center addObserverForName:NSApplicationWillTerminateNotification object:nil queue:NSOperationQueue.mainQueue
         usingBlock:^(NSNotification *note) {
        (void)note;
        for (NSWindow *window in bars.keyEnumerator) {
            objc_setAssociatedObject(window, &active_key, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [[bars objectForKey:window] orderOut:nil];
        }
        update_presentation();
    }];
    [center addObserverForName:NSWindowWillCloseNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        NSWindow *window = note.object;
        NSWindow *bar = [bars objectForKey:window];
        if (bar) { [bar orderOut:nil]; [bars removeObjectForKey:window]; }
        update_presentation();
    }];
    fprintf(stderr, "[EndfieldNotch] WineWindow v4 hooks installed: logical fullscreen geometry; affine input/poll/warp/clip; black top strip\n");
}

__attribute__((constructor)) static void initialize_endfield_notch(void)
{
    const char *enabled = getenv("ENDFIELD_NOTCH_SAFE");
    if (!enabled || strcmp(enabled, "1")) return;
    /* The C bootstrap loads this module only for Endfield. */
    dispatch_async(dispatch_get_main_queue(), ^{ install_hooks(); });
}
