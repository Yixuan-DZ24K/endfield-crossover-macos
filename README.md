# Endfield CrossOver macOS compatibility

Experimental compatibility sources for **Arknights: Endfield on Apple Silicon with CrossOver 26.3**. This repository includes Wine compatibility patches, DXMT configuration notes, and fixes for notched displays, the top menu-bar area, and fullscreen pointer mapping.

## Verified configuration

On October 15, 2026, the user confirmed normal resolution/fullscreen switching, notch avoidance, black top-strip behavior, and pointer clicks with the following configuration:

| Component | Tested configuration |
| --- | --- |
| Mac | Apple M5 Pro, 24 GB unified memory |
| macOS | 27.0.1, build 26A434 |
| CrossOver | 26.3, build 26.3.0.39832 |
| Game / launcher | Endfield 1.6.3 / GRYPHLINK 1.6.0 |
| Graphics backend | DXMT 0.74, DirectX 11 |
| Runtime options | MSync and Retina enabled |
| Display | 3024×1964; top safe-area inset of 32 points / 64 pixels |

This is a **source release recovered from the maintenance archive of the verified installation**. It includes all surviving repair sources and patches. The original full build directory was removed during cleanup, and a complete rebuild of the runtime from a fresh CrossOver source checkout has not been revalidated. This release is not a one-click installer and does not include CrossOver, the game, or a Bottle. Verification covers the reported checks on this configuration; other hardware, versions, and all gameplay scenarios have not been established.

## Repository contents

- `src/EndfieldNotch.m`: game-only Cocoa window handling, view scaling, an inert black top strip, and coordinate bridging.
- `src/loader.c`: a C bootstrap loaded at native Wine process startup that defers AppKit compatibility loading to the main thread.
- `src/geometry.h`: safe-area geometry and forward/inverse coordinate transforms.
- `src/endfield_coords.h`: the optional coordinate bridge interface used by the Wine driver.
- `patches/`: preserved Wine compatibility, driver coordinate, and historical safe-area metadata patches. Read the patch directory's documentation before applying them.
- `tests/` and `scripts/`: local builds and checks that do not modify an installed CrossOver application or Bottle.
- `docs/`: architecture, integration, validation scope, and source provenance.

## Build and test

Requires macOS, Xcode Command Line Tools, and Python 3. The standalone compatibility libraries target the x86_64 architecture used by Rosetta.

```sh
./scripts/build.sh
./scripts/test.sh
# On Apple Silicon, also test x86_64 after installing Rosetta:
./scripts/test.sh --arch x86_64
python3 scripts/check-publication.py
```

Build products are written to `build/`. These commands do not install anything into a running game or Bottle. Full integration requires a matching `winemac.so` with this repository's coordinate bridge patch; copying only the two new libraries is insufficient. Read [BUILDING.md](docs/BUILDING.md) and [INTEGRATION.md](docs/INTEGRATION.md) before integration.

## How the display fix works

The tested display has a native resolution of 3024×1964, while the visible area below the notch is 3024×1900. Reporting that smaller Cocoa window directly as the game's client area can leave the image and pointer coordinates inconsistent when the game still renders at the full height. The mismatch is most noticeable on controls near the bottom of the screen.

The v4 implementation preserves the Win32 logical rectangle requested by the game and scales the root view into the native safe area. Mouse events and position queries share the physical-to-logical transform; cursor warps and clipping use its inverse. Windowed mode returns to identity mapping.

While Endfield is active and fullscreen, a nonactivating black panel covers the top inset, and AppKit presentation options hide and disable the menu bar and Dock. Switching applications restores normal presentation. Cmd+Tab remains available.

## License and credits

Original standalone code, tests, tooling, and documentation use the [MIT license](LICENSE). Wine-derived patches retain **LGPL-2.1-or-later**. DXMT retains its upstream LGPL terms. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the component boundaries and attribution.

The compatibility foundation comes from [Endfield_FineWine](https://github.com/stoicswe/Endfield_FineWine), Wine, CodeWeavers, and dw-proton. Initial installation and troubleshooting referenced [rvacu/Endfield-CrossOver-Patcher](https://github.com/rvacu/Endfield-CrossOver-Patcher), and the resolution/fullscreen white-window recovery used [DXMT 0.74](https://github.com/3Shain/dxmt/releases/tag/v0.74). This repository is an independent source publication and is not an official release of those projects.

CrossOver, game, anti-cheat, and Apple proprietary binaries, Bottle registries, account data, and local troubleshooting logs are not distributed.
