# 游戏模式助手 GameModeHelper

[![build](https://github.com/2792178208-blip/GameModeHelper/actions/workflows/build.yml/badge.svg)](../../actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-black)](#系统要求)
[![Platform](https://img.shields.io/badge/Apple%20Silicon-only-orange)](#系统要求)

**[English](README_EN.md)** ｜ **[英文版仓库 EN repo](https://github.com/2792178208-blip/GameModeHelper-EN)** ｜ 中文

一个 macOS 桌面小工具（主窗口应用）：给**任意 App** 补上系统游戏模式声明，让它全屏运行时被 macOS
自动开启 **Game Mode**（CPU/GPU 优先调度、后台任务降载、蓝牙键鼠手柄采样率翻倍）。

> 典型场景：CrossOver / Whisky / Parallels 里的 Windows 游戏、RetroArch / OpenEmu 等模拟器、
> GeForce NOW 等串流客户端、Minecraft（Java）、各种没写游戏模式声明的老游戏——
> 系统不认为它们是游戏，全屏也不给开游戏模式。本工具替你把这一步补上。

> ⚠️ **免责声明**：本工具会修改第三方 App 的 `Info.plist` 并做 ad-hoc 重签（可随时一键还原）。
> 请只对你有权修改的 App 使用，风险自担。

## 目录

- [它是怎么工作的](#它是怎么工作的)
- [系统要求](#系统要求)
- [安装](#安装)
- [使用](#使用)
- [常见问题](#常见问题)
- [命令行](#命令行)
- [还原与卸载](#还原与卸载)
- [隐私与安全](#隐私与安全)
- [从源码构建](#从源码构建)
- [已知限制](#已知限制)
- [致谢](#致谢)

## 它是怎么工作的

macOS 的游戏模式由系统进程 `gamepolicyd` 负责：当**它认定为游戏**的 App 以**原生全屏**
（fullscreen space，⌃⌘F 那种）运行时，自动开启游戏模式。而"是不是游戏"来自 App 的
`Info.plist` 声明——很多游戏和模拟器没写，于是永远得不到游戏模式。

本工具做的事：

1. 在目标 App 的 `Info.plist` 里写入 `LSSupportsGameMode`（macOS 26+）/ `GCSupportsGameMode`
   （macOS 14+，旧键，两个都写以兼容）= `true`，并把分类设为游戏类
2. 做 ad-hoc 重签让 App 保持可启动（**选择性保留 `com.apple.security.*` entitlements**，
   沙盒 App 的存档与设置不受影响）
3. 刷新 LaunchServices 注册，让系统立刻认识新声明

效果可以用系统日志客观验证——开启后 `gamepolicyd` 会明确记录：

```
Found game GameProcess("你的游戏", pid=…, labelReason=LSSupportsGameMode (Info.plist))
Gaming session is now active …
Game mode status is now on.        ← 全屏时游戏模式正式开启
Game mode status is now off.       ← 退出后自动还原
```

完整判定链路：`IdentifiedGameGrant`（来自声明）→ `FrontmostGrant`（获得前台）→
`FullScreenGrant` + `ConsoleModeGrant`（原生全屏）→ **Game Mode on**。

## 系统要求

| 项目 | 要求 |
|---|---|
| 芯片 | Apple Silicon（游戏模式本身不支持 Intel Mac） |
| 系统 | macOS 14 Sonoma 及以上（14–15 走 `GCSupportsGameMode`，26+ 走 `LSSupportsGameMode`，本工具两个都写） |
| 构建 | Xcode Command Line Tools（`xcode-select --install`） |

## 安装

**方式一：下载打包好的 App**（见 Releases）

1. 下载 `GameModeHelper-vX.Y.Z-macOS.dmg`，打开后把 `GameModeHelper.app` 拖入右侧的「Applications」文件夹
3. 首次打开：右键点 App →「打开」→ 再点「打开」（绕过 Gatekeeper；App 未做公证）
   或在终端执行 `xattr -cr /path/to/GameModeHelper.app`

**方式二：从源码构建**

```bash
git clone https://github.com/2792178208-blip/GameModeHelper.git
cd GameModeHelper
./build.sh install   # 构建并安装到 ~/Applications
./selftest.sh        # 可选：跑一遍自检（12 项内置 + 6 项端到端）
```

## 使用

1. 打开「游戏模式助手」（标准窗口应用，有 Dock 图标；⌘Q 或关闭窗口即退出）
2. **列表只显示正在运行的 App**；前台 App 自动排最前、带「前台」徽标并自动选中——
   先启动游戏，再点开面板，游戏通常已经被选好了。点「刷新」可重新检测
3. 点「开启游戏模式支持」；需要管理员权限时**只输一次密码**（本次运行期间不再询问；
   也可以点底部的「管理员授权」提前授权）
4. 点「重启 App 生效」（会先征得你确认，正常退出再打开该 App——声明在进程启动时读取，
   不重启不生效）
5. 之后该 App 一进入原生全屏，macOS 就自动开启游戏模式；按 **⌘Esc** 呼出系统 Game Overlay
   可以查看/手动开关游戏模式

更详细的逐步说明见 **[docs/USAGE.md](docs/USAGE.md)**（用户手册）。

## Java / jar / 任意程序：游戏模式启动器

Minecraft（HMCL/PCL 启动）、各种 jar 工具、裸可执行程序没有 App 包，系统无法给它们游戏身份。
本工具可以把它们"包装"成带游戏声明的替身 App（GameStub 模式）：

1. 面板底部点 **「创建启动器…」**
2. 填写：替身名称、程序路径（可执行文件或 `.jar`，会自动包一层 `java -jar`）、启动参数、工作目录
3. 点「创建」——生成 `~/Applications/<名称>.app`，双击它即以游戏身份启动目标程序，
   全屏时自动开启游戏模式

### HMCL 接入指南（Minecraft 本体进游戏模式）

HMCL 自己拉起的 Minecraft 进程无法事后加入（游戏身份在进程启动时判定，实测已证伪"不重启
生效"）。正确做法：让 HMCL 经由替身启动 java——替身以游戏身份注册后把进程替换为真实 java，
Minecraft 天生继承身份。步骤：

1. 面板底部点「创建启动器…」→ 勾选 **透传模式** → 「创建」（Java 路径会自动探测；
   如果你的游戏用的是 HMCL 自带 JRE，把真实 Java 路径填成那个 JRE 的 `bin/java`）
2. 生成后记住这个路径：`~/Applications/<名称>.app/Contents/MacOS/GameStubRunner`
3. HMCL → 游戏实例设置（或全局设置）→ **Java** → 添加自定义 Java → 选择上面的
   `GameStubRunner` → 选中它作为该实例的 Java
4. 正常从 HMCL 启动 Minecraft（HMCL 探测/启动时实际调用的是替身，参数原样转交给真实 Java）
5. Minecraft 进入**原生全屏**（⌃⌘F 或窗口绿色按钮；游戏内"全屏"选项如果是无边框模式请改用
   系统全屏）→ 游戏模式自动开启

注意：替身注册身份约需 0.5 秒，HMCL 探测 Java 版本时会略微变慢，属正常；游戏输出不受影响。

## 常见问题

**开了游戏模式反而更卡？**
Game Mode 的调度策略（性能锁定、高刷新等）对个别游戏/机型可能是负优化（实测案例：
某机器上 HMCL 启动的 Minecraft 开启后帧率反而下降）。这不代表工具出了问题——按 **⌘Esc**
呼出 Game Overlay 把该 App 的游戏模式关掉即可（记忆为按 App 关闭，不影响其他游戏）；
或对本工具「还原默认」彻底回到原始状态。

**开了之后全屏还是没有游戏模式？**
按顺序检查：① 是否点过「重启 App 生效」（声明要重启才生效）；② 是否为**原生全屏**
（⌃⌘F）——无边框窗口/分屏/贴边最大化**不会**触发；③ 该 App 是否在只读系统卷上
（如 Safari，工具会明确提示「系统卷」且拒绝修改）。

**为什么运行中的 App 打补丁后必须重启？**
系统的进程分类在**启动那一刻**一次性判定。实测（`gamepolicyd` 日志）：对运行中的 App
注入声明并刷新注册后，哪怕它再做全屏切换，系统也不会重新识别它——这是系统机制，绕不过去。

**会影响 App 正常使用吗？**
只会改 `Info.plist` 的三个键，不碰任何资源文件；重签只保留 `com.apple.security.*`
entitlements（沙盒 App 的存档、设置不丢）。随时可「还原默认」回到原始状态。
唯一注意：App Store 版应用重签后脱离商店验证（本地使用不受影响）。

**会动我的其他程序吗？**
不会。工具不退出、不强杀任何进程；唯一发生的「重启」是你明确确认后的那一个 App。

**密码要输几次？**
第一次需要特权的操作输一次，本次运行期间全部免密（授权缓存在 App 进程内）。
App 重启后需要再输一次；想完全免密，可在 系统设置 → 隐私与安全性 → **App 管理**
中允许本工具（用户目录下的 App 即可零密码）。

**边框全屏（无边框窗口）可以吗？**
不可以。macOS 只在**原生全屏空间**触发游戏模式，这是系统行为。

## 命令行

```bash
BIN=GameModeHelper.app/Contents/MacOS/GameModeHelper
$BIN --list                  # 列出已安装 App 及游戏模式状态
$BIN --enable <路径或bundleID>   # 开启
$BIN --disable <路径或bundleID>  # 还原
$BIN --status <路径或bundleID>   # 查看状态
$BIN --restart <路径或bundleID>  # 重启该 App
$BIN --selftest [--dummy <路径>] # 内置自检
$BIN --auth-test             # 诊断：验证管理员授权缓存
```

## 还原与卸载

- **还原某个 App**：面板中选中它 →「还原默认」（会从备份恢复原始 Info.plist 并重签）
- **卸载工具**：先在面板底部点「退出」，然后：

```bash
mv ~/Applications/GameModeHelper.app ~/.Trash/
rm -rf ~/Library/Application\ Support/GameModeHelper ~/Library/Logs/GameModeHelper
```

（对已开启过支持的 App，先「还原默认」再卸载；之后重装工具也随时可以还原。）

## 隐私与安全

- 不联网、不收集任何数据；全部逻辑在本地
- 全程日志在 `~/Library/Logs/GameModeHelper/helper.log`，出问题可自查或附到 Issue
- 代码完全开源，无混淆无依赖（仅系统框架），可自行构建审计

## 从源码构建

```bash
./build.sh           # 构建 GameModeHelper.app（产物在项目根目录）
./build.sh install   # 构建并安装到 ~/Applications
./selftest.sh        # 内置自检 12 项 + 端到端 6 项
```

项目结构：

```
GameModeHelper/
├── Sources/            # Swift 源码（main / AppDelegate / HelperCore / PrivilegedRunner / Panel…）
├── Tools/makeicon.swift# 图标生成工具
├── docs/USAGE.md       # 用户手册
├── build.sh            # 构建脚本（swiftc 直接编译，无需 Xcode 工程）
├── selftest.sh         # 端到端自测
└── Info.plist
```

## 已知限制

- 游戏模式本身不支持 Intel Mac
- 运行中的 App 打补丁后**必须重启**才生效（系统机制，实验已证伪"不重启生效"的可能）
- 只读系统卷上的系统 App（如 Safari）无法修改
- 边框全屏（无边框窗口）不触发游戏模式——这是系统对"原生全屏"的硬性要求

## 致谢与参考

- [Apple 官方文档：LSSupportsGameMode](https://developer.apple.com/documentation/bundleresources/information-property-list/lssupportsgamemode) 与
  [WWDC25「Level up your games」](https://developer.apple.com/videos/play/wwdc2025/209)
- [nickzman/BetterGameMode](https://github.com/nickzman/BetterGameMode) —— 同类思路的先驱
  （基于 Xcode 的 gamepolicyctl 系统级开关；本工具用公开的 Info.plist 声明机制，无需 Xcode）
- [CeciliaStudio/MinecraftGameStub](https://github.com/CeciliaStudio/MinecraftGameStub) ——
  wrapper + execv 让游戏 PID 天生继承游戏身份的思路（MIT）
- [PrismLauncher #1644](https://github.com/PrismLauncher/PrismLauncher/issues/1644)、
  [SDL #8452](https://github.com/libsdl-org/SDL/issues/8452)、
  [mpv #14928](https://github.com/mpv-player/mpv/issues/14928) —— 社区对游戏模式的讨论
- [Apple 支持文档：使用游戏模式](https://support.apple.com/zh-cn/105118)

## License

[MIT](LICENSE)
