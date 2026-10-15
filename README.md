# Endfield CrossOver macOS compatibility

[中文](#中文) · [English](#english)

## 中文

这是《明日方舟：终末地》在 Apple Silicon Mac / CrossOver 26.3 上的一套实验性兼容修复源码，包含 Wine 兼容补丁、DXMT 使用记录，以及刘海屏、顶部菜单栏和全屏鼠标映射修复。

2026-10-15，使用者在下列配置中确认全屏、分辨率切换、刘海避让、顶部黑色区域及鼠标点击均正常：

| 项目 | 已测试配置 |
| --- | --- |
| Mac | Apple M5 Pro，24 GB 统一内存 |
| macOS | 27.0.1，build 26A434 |
| CrossOver | 26.3，build 26.3.0.39832 |
| 游戏 / 启动器 | Endfield 1.6.3 / GRYPHLINK 1.6.0 |
| 图形后端 | DXMT 0.74，DirectX 11 |
| 运行选项 | MSync、Retina 开启 |
| 显示器 | 3024×1964，安全区域顶部 32 points / 64 pixels |

这是一份从已验证安装的维护包恢复的**源码发布**，包含全部保留下来的修复源码和补丁。完整旧构建目录已清理，尚未重新验证从全新 CrossOver 源码重建完整运行环境。它目前不是一键安装器，也不附带 CrossOver、游戏或 Bottle。上表仅表示这一台机器上的使用者验证，不代表其他硬件、版本或所有游戏场景均已验证。

### 包含内容

- `src/EndfieldNotch.m`：仅在 Endfield 中启用的 Cocoa 窗口、视图缩放、黑色顶部区域与坐标桥接。
- `src/loader.c`：在原生 Wine 宿主启动时载入的 C 引导库，在主线程延后加载 AppKit 兼容组件。
- `src/geometry.h`：安全区域和正反方向坐标换算。
- `src/endfield_coords.h`：Wine 驱动使用的可选坐标桥接接口。
- `patches/`：保留的 Wine 兼容、驱动坐标和历史安全区域元数据补丁，详见补丁目录说明。
- `tests/`、`scripts/`：不修改现有 CrossOver 或 Bottle 的本地构建与检查。
- `docs/`：原理、部署步骤、验证范围和源代码出处。

### 构建与测试

需要 macOS、Xcode Command Line Tools 和 Python 3。构建目标是 Rosetta 使用的 x86_64 兼容库。

```sh
./scripts/build.sh
./scripts/test.sh
# 在 Apple Silicon 上，安装 Rosetta 后也可验证 x86_64：
./scripts/test.sh --arch x86_64
python3 scripts/check-publication.py
```

产物写入 `build/`。这些命令不会安装到运行中的游戏或 Bottle。完整集成需要带本仓库坐标桥接补丁的 `winemac.so`；单独复制两个新库并不足够。请先阅读 [BUILDING.md](docs/BUILDING.md) 和 [INTEGRATION.md](docs/INTEGRATION.md)。

### 修复思路

原生显示器为 3024×1964，而刘海下方实际可见区域是 3024×1900。如果把缩小后的 Cocoa 窗口尺寸直接当作游戏客户区，游戏仍按完整高度渲染时，底部显示与鼠标点击会不一致。

v4 保留游戏请求的 Win32 逻辑矩形，将根视图缩放到实际安全区域。鼠标事件和位置查询共用物理→逻辑坐标换算，光标定位和裁剪使用逆换算；窗口模式回到恒等映射。顶部区域在 Endfield 前台全屏时为纯黑，并通过 AppKit presentation options 隐藏和禁用菜单栏与 Dock，切换应用后恢复。

### 许可证与致谢

我们新增的源码、测试、工具和文档使用 [MIT](LICENSE)。Wine 派生补丁保留 **LGPL-2.1-or-later**；DXMT 也使用其上游 LGPL 条款。各组件的详细范围见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

兼容性基础来自 [Endfield_FineWine](https://github.com/stoicswe/Endfield_FineWine)、Wine、CodeWeavers 和 dw-proton 的工作。最初的安装与排查参考了 [rvacu/Endfield-CrossOver-Patcher](https://github.com/rvacu/Endfield-CrossOver-Patcher)，白屏恢复使用 [DXMT 0.74](https://github.com/3Shain/dxmt/releases/tag/v0.74)。本仓库是独立的源码整理，不是上述项目的官方版本。

## English

Experimental source and patches for Arknights: Endfield on Apple Silicon with CrossOver 26.3. The project includes Wine compatibility follow-up patches, DXMT configuration notes, a game-only safe-area window module, an inert black top strip, and coherent fullscreen input mapping.

The user confirmed normal resolution/fullscreen switching, notch avoidance, top-strip behavior, and pointer clicks on the configuration listed above on October 15, 2026. This is a recovered source snapshot, not a complete fresh-install reproducer or an installer. The original full Wine build tree was removed during cleanup; a clean end-to-end runtime rebuild has not been revalidated. Gameplay coverage beyond the reported checks is unspecified.

Build the standalone x86_64 libraries with `./scripts/build.sh`, run `./scripts/test.sh`, and read the integration documentation before using the sources. Build/test commands do not modify installed applications or Bottles. A matching patched `winemac.so` is required; copying only the two compatibility libraries is insufficient.

Original code, tooling, tests, and documentation are MIT licensed. Wine-derived patches retain LGPL-2.1-or-later and attribution; upstream dependencies retain their own licenses. CrossOver, game, anti-cheat and Apple proprietary binaries, Bottle registries, account data and local logs are not distributed.
