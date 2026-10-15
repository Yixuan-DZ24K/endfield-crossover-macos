// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Yixuan Zhang
#import <AppKit/AppKit.h>
#include <assert.h>
#include <math.h>
#include <stdio.h>

/* Only the production module's display queries use this fixture. AppKit's
   NSWindow/NSView implementations still use the real NSScreen class. A runner
   needs macOS AppKit, but neither a notched nor attached display. */
@interface EFTestScreen : NSObject
@property NSRect frame;
@property NSEdgeInsets safeAreaInsets;
+ (NSArray<EFTestScreen *> *)screens;
@end
static NSArray<EFTestScreen *> *test_screens;
@implementation EFTestScreen
+ (NSArray<EFTestScreen *> *)screens { return test_screens; }
@end

static NSRect reported;
static BOOL reported_fullscreen, reported_skip;
static unsigned report_count;

/* Minimal doubles for Wine's Objective-C entry points. The window and its
   child view are real native objects; neither is ever ordered onscreen. */
@interface WineWindow : NSWindow
@property BOOL fullscreen;
- (void)setFrameFromWine:(NSRect)frame;
- (void)updateFullscreen;
- (void)postWindowFrameChanged:(NSRect)frame fullscreen:(BOOL)fullscreen resizing:(BOOL)resizing skipSizeMove:(BOOL)skip;
- (void)windowDidResize:(id)note skipSizeMove:(BOOL)skip;
@end
@implementation WineWindow
- (NSRect)constrainFrameRect:(NSRect)rect toScreen:(NSScreen *)screen
{
    (void)screen;
    return rect;
}
- (void)setFrameFromWine:(NSRect)rect
{
    rect.origin.y = NSMaxY(test_screens[0].frame) - NSMaxY(rect);
    [self setFrame:[self frameRectForContentRect:rect] display:NO];
}
- (void)updateFullscreen {}
- (void)postWindowFrameChanged:(NSRect)frame fullscreen:(BOOL)full resizing:(BOOL)resize skipSizeMove:(BOOL)skip
{
    (void)resize;
    reported = frame;
    reported_fullscreen = full;
    reported_skip = skip;
    ++report_count;
}
- (void)windowDidResize:(id)note skipSizeMove:(BOOL)skip
{
    (void)note;
    [self postWindowFrameChanged:self.frame fullscreen:NO resizing:NO skipSizeMove:skip];
}
@end

@interface WineApplicationController : NSObject
- (NSUInteger)efNotchCoordinateBridgeVersion;
- (void)handleMouseButton:(NSEvent *)event;
@end
@implementation WineApplicationController
- (NSUInteger)efNotchCoordinateBridgeVersion { return 1; }
- (void)handleMouseButton:(NSEvent *)event { (void)event; }
@end

/* Compile the unmodified hook implementation with a deterministic display
   provider. This macro does not affect AppKit, imported above. */
#define NSScreen EFTestScreen
#include "../src/EndfieldNotch.m"
#undef NSScreen

static void near(CGFloat actual, CGFloat expected)
{
    if (!isfinite(actual) || fabs(actual - expected) >= 0.00001) {
        fprintf(stderr, "Expected %.8f; got %.8f\n", (double)expected, (double)actual);
        abort();
    }
}

static void near_point(CGPoint actual, CGPoint expected)
{
    near(actual.x, expected.x);
    near(actual.y, expected.y);
}

static void near_rect(CGRect actual, CGRect expected)
{
    near_point(actual.origin, expected.origin);
    near(actual.size.width, expected.size.width);
    near(actual.size.height, expected.size.height);
}

static void test_fullscreen(WineWindow *window, NSView *client, NSRect request, CGFloat inset)
{
    const CGRect physical = CGRectMake(0, inset, 1512, 982 - inset);
    unsigned before = report_count;
    [window setFrameFromWine:request];
    assert(is_enabled(window));
    assert(report_count > before);
    assert(reported_fullscreen && reported_skip);

    /* The native viewport shrinks, while the logical bounds and client
       surface retain the requested dimensions. The child visibly scales. */
    near(window.contentView.frame.size.width, physical.size.width);
    near(window.contentView.frame.size.height, physical.size.height);
    near(window.contentView.bounds.size.width, request.size.width);
    near(window.contentView.bounds.size.height, request.size.height);
    client.frame = NSMakeRect(0, 0, request.size.width, request.size.height);
    NSRect child_on_window = [client convertRect:client.bounds toView:nil];
    near(child_on_window.size.width, physical.size.width);
    near(child_on_window.size.height, physical.size.height);
    NSRect expected_report = request;
    expected_report.origin.y = 982 - NSMaxY(request);
    near_rect(NSRectToCGRect(reported), NSRectToCGRect(expected_report));

    /* Exercise the dynamically installed selectors, including ABI-sensitive
       CGPoint/CGRect returns. No hardware cursor is moved. */
    for (int x = 0; x <= 20; ++x) for (int y = 0; y <= 20; ++y) {
        CGFloat u = x / 20.0, v = y / 20.0;
        CGPoint physical_point = CGPointMake(physical.origin.x + physical.size.width * u,
                                             physical.origin.y + physical.size.height * v);
        CGPoint logical_point = CGPointMake(request.origin.x + request.size.width * u,
                                            request.origin.y + request.size.height * v);
        near_point(ef_notch_logical_point(window, physical_point), logical_point);
        near_point(ef_notch_physical_point(window, logical_point), physical_point);
    }
    near_rect(ef_notch_logical_rect(window, physical), NSRectToCGRect(request));
    near_rect(ef_notch_physical_rect(window, NSRectToCGRect(request)), physical);
    near_point(ef_notch_delta_scale(window),
               CGPointMake(request.size.width / physical.size.width,
                           request.size.height / physical.size.height));

    /* Reapplying an already clamped native frame must still report logical
       Win32 geometry. This covers the original resize-event loss. */
    before = report_count;
    [window setFrameFromWine:request];
    assert(report_count > before);
    near_rect(NSRectToCGRect(reported), NSRectToCGRect(expected_report));
    assert(!window.visible);
    assert(bars.count == 0);
    assert(!owns_presentation);
}

int main(void)
{
    @autoreleasepool {
        /* scripts/test.sh also clears this before the source constructor. */
        unsetenv("ENDFIELD_NOTCH_SAFE");
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        EFTestScreen *screen = [EFTestScreen new];
        screen.frame = NSMakeRect(0, 0, 1512, 982);
        screen.safeAreaInsets = NSEdgeInsetsMake(32, 0, 0, 0);
        test_screens = @[screen];
        install_hooks();

        WineWindow *window = [[WineWindow alloc] initWithContentRect:screen.frame
            styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:YES];
        window.releasedWhenClosed = NO;
        NSView *client = [[NSView alloc] initWithFrame:screen.frame];
        [window.contentView addSubview:client];
        test_fullscreen(window, client, screen.frame, 32);
        screen.safeAreaInsets = NSEdgeInsetsMake(37, 0, 0, 0);
        test_fullscreen(window, client, NSMakeRect(0, 18.5, 1512, 945), 37);

        window.styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskResizable;
        [window setFrameFromWine:NSMakeRect(100, 100, 1280, 800)];
        assert(!is_enabled(window));
        near(window.contentView.bounds.size.height, window.contentView.frame.size.height);
        near_point(ef_notch_logical_point(window, CGPointMake(200, 250)), CGPointMake(200, 250));
        near_point(ef_notch_physical_point(window, CGPointMake(200, 250)), CGPointMake(200, 250));
        near_point(ef_notch_delta_scale(window), CGPointMake(1, 1));

        /* A display without a notch remains an identity fullscreen path. */
        screen.safeAreaInsets = NSEdgeInsetsMake(0, 0, 0, 0);
        window.styleMask = NSWindowStyleMaskBorderless;
        [window setFrameFromWine:screen.frame];
        assert(!is_enabled(window));
        near_point(ef_notch_logical_point(window, CGPointMake(1500, 970)), CGPointMake(1500, 970));

        NSWindow *unrelated = [[NSWindow alloc] initWithContentRect:NSMakeRect(10, 10, 300, 300)
            styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:YES];
        unrelated.releasedWhenClosed = NO;
        near_point(ef_notch_logical_point(unrelated, CGPointMake(22, 33)), CGPointMake(22, 33));
        near_point(ef_notch_physical_point(unrelated, CGPointMake(22, 33)), CGPointMake(22, 33));
        assert(!window.visible && !unrelated.visible && bars.count == 0);
        [window close];
        [unrelated close];
        puts("Bridge checks passed: native child-view scaling; logical frame notifications; 882-point selector/inverse grid; warp/clip rectangles; windowed and non-notched identity. No windows shown or cursor moved.");
    }
    return 0;
}
