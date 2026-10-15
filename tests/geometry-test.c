// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Yixuan Zhang
#include "geometry.h"
#include <assert.h>
#include <stdio.h>

static void close_point(CGPoint actual, CGPoint expected)
{
    assert(fabs(actual.x - expected.x) < 0.000001);
    assert(fabs(actual.y - expected.y) < 0.000001);
}

static void test_affine(void)
{
    CGRect physical = CGRectMake(0, 32, 1512, 950);
    CGRect logical = CGRectMake(0, 0, 1512, 982);
    /* A rendered target at each normalized location must produce the same
       normalized Win32 client coordinate, including both bottom corners. */
    for (int x = 0; x <= 20; ++x) for (int y = 0; y <= 20; ++y) {
        double u = x / 20.0, v = y / 20.0;
        CGPoint point = CGPointMake(physical.origin.x + physical.size.width * u,
                                    physical.origin.y + physical.size.height * v);
        CGPoint mapped = ef_map_point(point, physical, logical);
        close_point(mapped, CGPointMake(1512 * u, 982 * v));
        close_point(ef_map_point(mapped, logical, physical), point);
    }
    close_point(ef_map_point(CGPointMake(0, 32), physical, logical), CGPointZero);
    close_point(ef_map_point(CGPointMake(1512, 982), physical, logical), CGPointMake(1512, 982));
    /* 3024x1890 and offset desktops use their own window origins/sizes. */
    CGRect logical1610 = CGRectMake(0, 18.5, 1512, 945);
    close_point(ef_map_point(CGPointMake(756, 507), physical, logical1610), CGPointMake(756, 491));
    CGRect second = CGRectMake(1512, -168, 1512, 950);
    CGRect virtualSecond = CGRectMake(1512, -200, 1512, 982);
    close_point(ef_map_point(CGPointMake(1512, -168), second, virtualSecond), CGPointMake(1512, -200));
    close_point(ef_map_point(CGPointMake(2400, 500), physical, physical), CGPointMake(2400, 500));
    close_point(ef_map_point(CGPointMake(30, 50), CGRectZero, logical), CGPointMake(30, 50));
    /* Regression: at 95% height, raw input minus the safe-area offset
       understated the logical Y by 30.4 points (60.8 Retina pixels). */
    CGPoint bottom = CGPointMake(1450, 32 + 950 * .95);
    CGPoint mapped = ef_map_point(bottom, physical, logical);
    assert(fabs(mapped.y - (bottom.y - 32) - 30.4) < 0.000001);
}

int main(void)
{
    CGRect screen = CGRectMake(0, 0, 1512, 982), result;
    assert(ef_safe_frame(screen, screen, 37, 0, &result));
    assert(CGRectEqualToRect(result, CGRectMake(0, 37, 1512, 945)));
    assert(CGRectGetMaxY(result) == CGRectGetMaxY(screen));
    assert(ef_safe_frame(CGRectMake(0, 18.5, 1512, 945), screen, 37, 0, &result));
    assert(CGRectEqualToRect(result, CGRectMake(0, 37, 1512, 945)));
    assert(ef_safe_frame(result, screen, 37, 0, &result));
    assert(CGRectEqualToRect(result, CGRectMake(0, 37, 1512, 945)));
    assert(!ef_safe_frame(screen, screen, 0, 0, &result));
    assert(!ef_safe_frame(screen, screen, 37, 1, &result));
    assert(!ef_safe_frame(CGRectMake(116, 72, 1280, 800), screen, 37, 0, &result));
    CGRect second = CGRectMake(1512, -200, 1512, 982);
    assert(ef_safe_frame(second, second, 37, 0, &result));
    assert(CGRectEqualToRect(result, CGRectMake(1512, -163, 1512, 945)));
    test_affine();
    puts("Geometry checks passed: notch boundaries; 441-point affine grid; corner/edge reachability; inverse warp/clip; 16:10; offset monitor; identity.");
    return 0;
}
