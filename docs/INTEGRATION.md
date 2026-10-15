# Manual integration model

This describes the verified deployment design. It is not an automated fresh-runtime installer. Start with your own compatible CrossOver installation and a rebuilt, matched Wine/DXMT runtime; preserve working copies before local integration.

## Private runtime per Bottle

The final installation uses the original `Arknights Endfield` Bottle and its original ID/menu entries. Required runtime files live under:

```text
<Bottle>/.endfield-runtime/CrossOver/
```

The original CrossOver application and other Bottles keep their own runtime files. A Bottle-scoped CrossOver configuration selects this runtime through supported wrapper configuration fields:

```ini
[EnvironmentVariables]
"CX_ROOT" = "${WINEPREFIX}/.endfield-runtime/CrossOver"
"CX_GRAPHICS_BACKEND" = "dxmt"
"WINED3DMETAL" = "0"
"WINEDXVK" = "0"
"WINEESYNC" = "0"
"WINEMSYNC" = "1"
"ENDFIELD_NOTCH_SAFE" = "1"

[Wine]
"BinPath" = "${WINEPREFIX}/.endfield-runtime/CrossOver/bin"
"LibPath" = "${WINEPREFIX}/.endfield-runtime/CrossOver/lib"
```

Merge the appropriate values into the existing sections of `cxbottle.conf`; do not create duplicate sections or change the Bottle ID. These fields were verified with the installed CrossOver 26.3 wrapper, not asserted for arbitrary versions. Retina is also enabled in the tested Bottle. Keep game resolution/fullscreen choices intact.

## Compatibility module and startup

1. The native Wine executable must load the pure-C `EndfieldNotchLoader.dylib` at native process startup. Loading it as a late dependency of DXMT caused a Cocoa/dyld startup deadlock in the earlier experiment.
2. The bootstrap activates only when `ENDFIELD_NOTCH_SAFE=1` and the process arguments or `WINEPRELOADERAPPNAME` identify Endfield. It schedules the adjacent `EndfieldNotch.dylib` on the main dispatch queue.
3. The Wine driver must carry `Endfield-winemac-coordinate-v4.patch`. The Objective-C module checks `efNotchCoordinateBridgeVersion` before installing its hooks; it remains inactive if that driver interface is missing.
4. The Wine executable is copied into a temporary location by CrossOver. Therefore, the bootstrap's `LC_LOAD_DYLIB` dependency must point to its **absolute installed path**, rather than resolving relative to the temporary executable's `@loader_path`.
5. Preserve existing executable entitlements/flags when locally re-signing a relocated loader. Verify native libraries and the final loader after local signing. Do not reuse a dependency path from another person's installation.

The original verified deployment inserted the new load command into available Mach-O header padding and then re-signed the executable, preserving its code/data body. A local implementation must validate the Mach-O architecture, load-command bounds and available padding; this repository intentionally has no blind binary-edit installer.

## Window and pointer mapping

The native content frame is constrained below `NSScreen.safeAreaInsets.top` only for matching fullscreen-like, borderless Endfield windows on a notched screen. The Win32 logical frame remains what the game requested, while the content view's bounds preserve that logical size. This allows the full Metal view to scale into the smaller native viewport.

Physical hit testing and native clipping happen first. The Wine bridge then maps absolute positions into logical screen coordinates before Retina conversion. Cursor polling uses the same mapping; warps and clip rectangles use the inverse. Queued cursor-warp updates and frame queries follow that convention too. Relative deltas keep their accumulated fractional remainder after scaling.

The black top panel cannot become the key/main window and consumes pointer events. While the game is active/fullscreen, AppKit hides and disables the menu bar and Dock; windowing, minimizing, app switching and closing restore presentation state. Cmd+Tab remains available.

## Normal launch and recovery

Start Endfield through GRYPHLINK with DirectX 11 checked. A direct `Endfield.exe` launch previously failed the game's official-launcher requirement.

For a functional check, test the centers of right-upper Settings, central confirmation controls, lower-right Asia and lower-left power/cancel, then switch resolution/fullscreen/windowed mode and use Cmd+Tab. Match pixels and logical points carefully on Retina displays.

To disable only this display module for diagnosis, remove/disable `ENDFIELD_NOTCH_SAFE` in the Bottle's environment after closing its processes. This removes the module's notch/menu/input behavior together. The rest of the custom Wine compatibility runtime remains a separate dependency; restoring an unpatched runtime can reintroduce the original launch failure.

## Local diagnostics

The compatibility module writes status/geometry messages to stderr and records at most the first 80 fullscreen left-button down events per process, including physical/logical pointer positions. This is local diagnostic output, not network telemetry; review logs before sharing them. The publication does not include any troubleshooting-session logs.
