# Building and source provenance

## Standalone libraries

Run `./scripts/build.sh` on macOS with Xcode Command Line Tools. It compiles and ad-hoc signs:

- `build/EndfieldNotch.dylib`: x86_64 AppKit/Objective-C module, minimum deployment target macOS 15.
- `build/EndfieldNotchLoader.dylib`: x86_64 C bootstrap using the main dispatch queue.

The build command writes only to the repository's `build/` directory. It neither copies files to an application/Bottle nor stops Wine processes.

`./scripts/test.sh` checks geometry and the AppKit bridge. `--arch x86_64` exercises the Rosetta architecture when available. Test harness edits made for publication do not change the production compatibility algorithm; the screen provider is synthetic so physical notch hardware is unnecessary.

## Wine source base

The tested runtime used CodeWeavers CrossOver **26.3 / build 26.3.0.39832**, whose Wine source reports Wine 11.0, with the FineWine compatibility base and the follow-up patches retained here.

Known primary inputs:

- [CrossOver 26.3 public source package](https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.3.0.tar.gz).
- [FineWine 1.2.2](https://github.com/stoicswe/Endfield_FineWine/tree/1.2.2), currently resolving to commit `3d3fbec2b6bb0afb8e3de614ef70acd5eaa7113d`.
- The patches in this repository, with the standalone safe-area patch treated as a historical duplicate.
- [DXMT 0.74](https://github.com/3Shain/dxmt/releases/tag/v0.74).

The separate MoltenVK/SPIRV-Cross patch sets are not inputs to the DXMT display fix described here. See the [pinned upstream build script](https://github.com/stoicswe/Endfield_FineWine/blob/3d3fbec2b6bb0afb8e3de614ef70acd5eaa7113d/scripts/build-wine.sh) for the baseline recipe.

The exact old configure command, full source checkout and intermediate objects were removed during user-requested cleanup. The maintenance archive retained the displayed source modules and diffs. Consequently, this publication proves that the standalone source components build and their tests run; it does **not** establish a fully reproducible rebuild of every installed Wine binary from an empty checkout.

A reconstruction must inspect FineWine's 24 Wine patches in order (em-backports, misc, then stage1-macos), validate the candidate Wine tree, and build for the x86_64 host/Windows targets used by the Rosetta configuration. Avoid using only FineWine's default module list: these follow-up changes also require a matched `wineserver`, `wineboot.exe`, `csrss.exe`, `lsass.exe`, and `winemac.so`, along with the affected `ntdll.so` and `ntoskrnl.exe`. The successful installation retained the stock PE `ntdll.dll`; an earlier experimental replacement was reverted.

Generated server request headers and tables must agree with the server executable. Do not transplant protocol enums into an otherwise unmatched runtime.

## DXMT

The tested release archive was `dxmt-v0.74-builtin.tar.gz`, SHA-256:

```text
2598981a8b725653773e277470a95dda4253b8a14d36e0dc96dce0e3800f0ceb
```

This is a reference to an external dependency, not a bundled binary or a promise that a future upstream asset will have the same contents. The successful private runtime used a local loader RPATH adjustment and local ad-hoc signing. Its installed `winemetal.so` SHA-256 was `dfd3a3c8065077db36dc889f900619e703a1463400ae8d8f985830341a915d0c`, which differs from an untouched upstream archive member because of those loader/signature changes.

Use the complete coherent x86_64/i386 DXMT release components appropriate to the runtime, preserving upstream notices. DXMT 0.74 replaced the previously bundled build and resolved the reported white window during resolution/fullscreen changes on the tested machine.
