# Validation record and limits

## Manual user verification

On 2026-10-15, after the v4 coordinate patch, the user reported that all requested checks were normal. The requested checks covered:

- Fullscreen at 3024×1964, including Asia and power/cancel at the visual button centers and right-upper Settings.
- The reported resolution/windowed/fullscreen white-window issue, after installing DXMT 0.74.
- Top controls below the physical notch.
- A black, inactive top menu-bar area and recovery of normal presentation on app switching.
- Correct pointer positions across the screen, including the bottom corners.

This is a user report on one configuration, not an automated gameplay certification or proof of other versions/hardware. Earlier reports that general controls aligned were superseded by a later bottom-corner regression; only the final v4 report is treated as the final display/input result.

## Source-level checks

- Geometry checks cover safe-area matching, centered 16:10 requests, idempotence, ordinary-window exclusion, screens without an inset, and monitor offsets.
- A 441-point affine grid checks normalized target alignment and inverse mapping, including corner/edge reachability.
- The AppKit harness checks the production Objective-C hook ABI, native content-view/child scaling, logical frame notifications, inverse cursor warps and clip rectangles, and return to identity mapping for windowed/unrelated windows.
- Publication-time adaptations use a synthetic screen provider in the test translation unit; production source behavior is unchanged.

## Final local migration

The working files and settings were migrated into the original named Bottle while preserving its ID and menu entries. The migration verified 977 transferred/core files, compared 5,185 retained runtime files (only the relocated loader's dependency/signature differed), and checked 6,017 protected original-application/unrelated-Bottle files. The official launcher was then verified to load the original Bottle's private Wine/DXMT runtime.

A separate post-migration manual game test was not recorded. Prior successful user verification and migration consistency are distinct evidence. Logs, account data, registry exports, personal paths and device/Bottle identifiers used during local troubleshooting are not included in this public record.

## Rebuild limitation

The standalone component build and tests are runnable from this repository. A complete fresh rebuild of the Wine runtime from the published base sources has not been revalidated since cleanup. CI does not test game startup, a live anti-cheat connection, actual gameplay, account login or visual behavior on physical notch hardware.
