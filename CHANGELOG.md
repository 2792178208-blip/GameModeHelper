# 更新日志 Changelog

本项目的所有重要变更都会记录在此文件中。
格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.1.0] - 2026-10-25

### 新增

- **游戏模式启动器**：为 Java/jar、裸可执行程序生成带游戏声明的替身 App
  （GameStub 模式，运行器以 App 身份注册后 execv 目标程序，PID 继承游戏身份）
- **HMCL 全自动接入**：面板显示正在运行的裸程序（java 等）；选中点开启即自动
  生成包装器并写入 HMCL 全部实例的包装命令——同时支持新设置系统
  （`instance-game-settings.json` + `overrideProperties` + 全局 preset）与旧版
  `hmclversion.cfg`，全部带备份可一键还原；HMCL 重启后生效
- 透传模式（实验性）：替身运行器可作为启动器的"自定义 Java"被调用，参数原样转交
- 运行器诊断日志（`~/Library/Logs/GameModeHelper/wrapper.log`）
- CLI 新增 `--auth-test`（管理员授权缓存诊断）
- 面板底部新增「退出」入口（确认对话框；接线配置与备份保留，随时可重新打开）

### 修复

- 运行中的 App 开启失败：改用 Sparkle 式副本替换补丁，失败自动回滚
- 重签丢失沙盒 entitlements → 选择性保留 `com.apple.security.*`
- 管理员密码反复弹窗 → AuthorizationRef 会话内一次授权复用
- 只读系统卷（Safari 等）误弹密码框 → 明确拒绝并说明
- HMCL 接线的成功提示被列表刷新覆盖、重复点击产生多个替身 → 提示稳定显示 + 幂等收敛固定路径
- 自检挂死：改为先优雅退出假 App 再还原（全程零密码，33 秒跑完）

### 已知限制

- 游戏身份在进程启动时判定：已运行的进程无法事后加入（需重启该 App/游戏）
- HMCL 接线需重启 HMCL 后生效（其设置仅启动时读取）
- Game Mode 调度因游戏和机型而异，个别游戏（如某些机器上的 Minecraft Java）开启后
  可能反而变卡——按 ⌘Esc 可随时按 App 关闭

## [1.0.0] - 2026-10-25

首个公开发布版本。

### 新增

- 为任意 App 补上 macOS 系统游戏模式声明（`LSSupportsGameMode` / `GCSupportsGameMode` +
  游戏分类），使其在原生全屏运行时被系统自动开启游戏模式
- 面板只显示正在运行的 App，前台 App 自动排最前并选中；手动「刷新」按钮（无后台轮询）
- 「选择 App…」支持挑选未运行的 App（适合还没启动的游戏）
- 正在运行的 App 使用「副本替换」方式打补丁（Sparkle 同款机制），失败自动回滚
- 重签时选择性保留 `com.apple.security.*` entitlements，沙盒 App 的存档与设置不丢失
- 一键还原（从备份恢复原始 Info.plist 并重签）；只读系统卷（SIP）上的 App 明确拒绝并说明
- 管理员授权一次，本次运行期间所有特权操作免密（AuthorizationRef 会话缓存）
- 重启 App 生效：优雅退出失败时自动降级为 SIGTERM（需用户确认重启）
- 菜单栏常驻（LSUIElement），全程日志（`~/Library/Logs/GameModeHelper/helper.log`）
- 内置自检（12 项）与端到端自测（6 项）：`./selftest.sh`
- CLI 完整命令行：`--list / --enable / --disable / --status / --restart / --selftest / --auth-test`
