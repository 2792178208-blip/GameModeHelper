# 更新日志 Changelog

本项目的所有重要变更都会记录在此文件中。
格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.1.0] - 2026-10-25

### 新增

- 游戏模式启动器：为 Java/jar、裸可执行程序生成带游戏声明的替身 App（GameStub 模式，
  execv 继承身份），把可用范围扩展到没有 App 包的程序；含透传模式（实验性）

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
