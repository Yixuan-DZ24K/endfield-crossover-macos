/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Yixuan Zhang
 */
#include <CoreGraphics/CoreGraphics.h>
#include <math.h>

/* Map a top-down desktop point between the native safe-area viewport and
   the unmodified rectangle requested by Win32. The same transform is used
   for events and cursor polling, and its inverse for warps/clipping. */
static CGPoint ef_map_point(CGPoint point, CGRect source, CGRect destination)
{
    if (source.size.width <= 0 || source.size.height <= 0 ||
        destination.size.width <= 0 || destination.size.height <= 0)
        return point;
    return CGPointMake(destination.origin.x +
                       (point.x - source.origin.x) * destination.size.width / source.size.width,
                       destination.origin.y +
                       (point.y - source.origin.y) * destination.size.height / source.size.height);
}

/* Wine passes rectangles in Cocoa points, with a top-down desktop origin. */
static int ef_safe_frame(CGRect requested, CGRect screen, double inset,
                         int decorated, CGRect *result)
{
    *result = requested;
    if (decorated || inset <= 0 || inset >= screen.size.height / 4)
        return 0;
    if (fabs(requested.origin.x - screen.origin.x) > 2 ||
        fabs(requested.size.width - screen.size.width) > 2 ||
        requested.origin.y < screen.origin.y - 2 ||
        requested.origin.y > screen.origin.y + inset + 2 ||
        requested.size.height < screen.size.height - inset - 2 ||
        requested.size.height > screen.size.height + 2)
        return 0;
    *result = CGRectMake(screen.origin.x, screen.origin.y + inset,
                         screen.size.width, screen.size.height - inset);
    return 1;
}
