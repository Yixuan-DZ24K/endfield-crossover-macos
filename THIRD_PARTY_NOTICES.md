# License scope and upstream notices

The root [MIT license](LICENSE) covers original standalone code in `src/`, original tests and scripts, and project documentation. It does not relicense third-party work. Copyright and license notices embedded in imported material remain in effect.

| Material | Terms / attribution |
| --- | --- |
| Original standalone sources, tests, tooling and documentation | MIT, Copyright (c) 2026 Yixuan Zhang |
| `patches/*.patch` modifications to Wine sources | LGPL-2.1-or-later, with upstream Wine/CodeWeavers and credited contributor notices retained |
| Original `endfield_coords.h` bridge interface, also embedded as a new file in the coordinate patch | MIT as standalone source; it may be combined with the LGPL Wine driver under the applicable combined-work terms |
| Wine and CodeWeavers Wine source base | LGPL-2.1-or-later for Wine; preserve per-file notices and any other source-package licenses |
| FineWine original research and upstream changes | Credit stoicswe/Endfield_FineWine, bluechxin, dw-proton/Dawn Winery (including Etaash Mathamsetty, Ziia Shi / mkrsym1, and NelloKudo), and the contributors identified by the source; Wine-derived changes retain LGPL terms |
| DXMT (external dependency, not bundled) | LGPL-2.1-or-later, Copyright (c) 2023–2026 Feifan He for CodeWeavers |
| rvacu/Endfield-CrossOver-Patcher (reference project, not vendored) | Retains its own license and notices |

The complete LGPL 2.1 text is included in [LICENSES/LGPL-2.1-or-later.txt](LICENSES/LGPL-2.1-or-later.txt). The “or later” permission comes from the upstream notices; the included license text itself is unmodified.

Primary references:

- [Wine license](https://github.com/wine-mirror/wine/blob/master/LICENSE) and [COPYING.LIB](https://github.com/wine-mirror/wine/blob/master/COPYING.LIB).
- [DXMT license](https://github.com/3Shain/dxmt/blob/main/LICENSE).
- [Endfield_FineWine](https://github.com/stoicswe/Endfield_FineWine).
- [Endfield-CrossOver-Patcher notices](https://github.com/rvacu/Endfield-CrossOver-Patcher/blob/main/THIRD_PARTY_NOTICES.md).
- [CodeWeavers public source packages](https://media.codeweavers.com/pub/crossover/source/).

No CrossOver application/runtime binaries, Endfield/GRYPHLINK/ACE binaries, Game Porting Toolkit, proprietary assets, registry exports, credentials or user logs are included. If you distribute your own rebuilt Wine components, preserve their notices and provide corresponding source and build materials as required by their licenses. This repository's MIT license grants no additional rights to external products or trademarks.
