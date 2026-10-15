/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Yixuan Zhang
 */
/* Optional, process-local coordinate bridge for the isolated Endfield host.
 * No selector implementation is installed in other applications.  All calls
 * occur on the Cocoa main thread, after physical hit testing and clipping.
 */
#import <AppKit/AppKit.h>

@protocol EFNotchCoordinates
- (CGPoint)efNotchLogicalPointForPhysicalPoint:(CGPoint)point;
- (CGPoint)efNotchPhysicalPointForLogicalPoint:(CGPoint)point;
- (CGRect)efNotchLogicalRectForPhysicalRect:(CGRect)rect;
@end

static inline CGPoint ef_notch_logical_point(NSWindow *window, CGPoint point)
{
    if ([window respondsToSelector:@selector(efNotchLogicalPointForPhysicalPoint:)])
        return [(id<EFNotchCoordinates>)window efNotchLogicalPointForPhysicalPoint:point];
    return point;
}

static inline CGPoint ef_notch_physical_point(NSWindow *window, CGPoint point)
{
    if ([window respondsToSelector:@selector(efNotchPhysicalPointForLogicalPoint:)])
        return [(id<EFNotchCoordinates>)window efNotchPhysicalPointForLogicalPoint:point];
    return point;
}

static inline CGRect ef_notch_logical_rect(NSWindow *window, CGRect rect)
{
    if ([window respondsToSelector:@selector(efNotchLogicalRectForPhysicalRect:)])
        return [(id<EFNotchCoordinates>)window efNotchLogicalRectForPhysicalRect:rect];
    return rect;
}

static inline CGRect ef_notch_physical_rect(NSWindow *window, CGRect rect)
{
    CGPoint a = ef_notch_physical_point(window, rect.origin);
    CGPoint b = ef_notch_physical_point(window, CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)));
    return CGRectMake(a.x, a.y, b.x - a.x, b.y - a.y);
}

static inline CGPoint ef_notch_delta_scale(NSWindow *window)
{
    CGPoint a = ef_notch_logical_point(window, CGPointZero);
    CGPoint b = ef_notch_logical_point(window, CGPointMake(1, 1));
    return CGPointMake(b.x - a.x, b.y - a.y);
}
