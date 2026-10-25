# 游戏模式助手 · 用户手册

本手册面向日常使用，逐步说明每个功能、授权流程、故障排查与卸载方法。
原理性内容见项目根目录 [README](../README.md)。

---

## 1. 准备工作

| 检查项 | 说明 |
|---|---|
| 电脑 | Apple Silicon Mac（M1/M2/M3/M4 系列；Intel 机型系统不支持游戏模式） |
| 系统 | macOS 14 Sonoma 或更高 |
| 游戏 | 任何"全屏时系统不给开游戏模式"的 App |

> 名词解释：**原生全屏**指按 ⌃⌘F 或点绿色按钮进入的全屏（整个屏幕独占、菜单栏自动隐藏）。
> macOS 只在这种全屏下触发游戏模式；无边框窗口、分屏、贴边最大化都不算。

## 2. 安装与首次启动

**方式一：使用打包好的 App（推荐）**

1. 从 GitHub Releases 下载 `GameModeHelper-vX.Y.Z-macOS.zip`，解压
2. 把 `GameModeHelper.app` 拖入「访达 → 前往 → 个人主目录 → 应用程序」（即 `~/Applications`）
3. 双击打开会提示"无法验证开发者"——这是正常的（App 未做公证）。两种解决办法：
   - 右键点 App →「打开」→ 再点「打开」
   - 或终端执行：`xattr -cr ~/Applications/GameModeHelper.app`

**方式二：源码构建**

```bash
git clone https://github.com/OWNER/GameModeHelper.git
cd GameModeHelper && ./build.sh install
```

**首次启动后**：菜单栏右上角出现 🎮 手柄图标。App 纯菜单栏常驻、没有 Dock 图标。

## 3. 给 App 开启游戏模式（核心流程）

1. **先启动你的游戏**（让它在运行）
2. 点菜单栏 🎮 图标，打开面板
3. 列表里**只显示正在运行的 App**：
   - 前台 App 排在第一位，带蓝色「前台」徽标，并已自动选中
   - 如果列表里没有你要的（游戏还没启动），点「选择 App…」手动挑选任何 `.app`
   - 列表不是实时的：点「刷新」按钮重新检测
4. 确认选中游戏后，点 **「开启游戏模式支持」**
   - 弹出系统密码框时输入一次即可（本次运行期间后续操作都不再询问）
   - 提示「✅ 已开启游戏模式支持」即成功；失败会给出具体原因
5. 点 **「重启 App 生效」**，在确认框里再点「重启」
   - 为什么必须重启：系统的"游戏身份"在进程启动那一刻判定，之后改声明不会重新识别
   - App 会正常退出再自动打开（只重启这一个 App，未保存内容请先保存）
6. 把游戏切到**原生全屏**（⌃⌘F），macOS 会自动开启游戏模式
7. 验证：按 **⌘Esc** 呼出系统 Game Overlay 查看游戏模式状态；部分情况下菜单栏也会出现
   游戏手柄图标

## 4. 授权说明（密码只输一次）

- 第一次需要管理员权限的操作会弹系统密码框，**输一次后本会话内不再询问**
- 也可以在面板底部点 **「管理员授权」** 提前授权
- 授权随 App 进程存活：重启电脑或重启本工具后，下一次特权操作再输一次
- **想彻底免密**：系统设置 → 隐私与安全性 → **App 管理** → 添加允许「GameModeHelper」，
  之后用户目录下的 App 完全零密码（/Applications 下 root 属主的 App 仍会要一次密码，系统要求）
- 密码框可以取消，取消后操作中止、不会有任何改动
- 诊断命令：`GameModeHelper --auth-test`（同进程两次特权操作，第二次应 <1 秒）

## 5. Java / jar / 任意程序：创建游戏模式启动器

Minecraft（HMCL 启动）、jar 工具这类**没有 App 包**的程序，系统无法直接给它们游戏身份
（游戏身份在进程启动时判定，运行中的进程无法事后注入——实测已验证）。
解决办法：为它们生成一个**带游戏模式声明的替身 App**。

**操作步骤**：

1. 面板底部点 **「创建启动器…」**
2. 填写表单：
   - **名称**：替身 App 的显示名（如"Minecraft 游戏模式"）
   - **程序**：可执行文件路径，或 `.jar` 文件（选 .jar 会自动包一层 `java -jar`，
     Java 路径自动探测；HMCL 自带 JRE 的话可以之后手改 config）
   - **参数**：启动参数（可选）
   - **工作目录**：可选，默认程序所在目录
3. 点「创建」→ 生成 `~/Applications/<名称>.app`
4. **双击替身 App** 启动目标程序 → 它天生携带游戏身份 → 原生全屏时自动开启游戏模式

**原理**：替身 App 自带游戏声明；其运行器以 App 身份启动注册后，把进程镜像替换（execv）
为真正的游戏程序——PID 不变，身份继承。实测 `gamepolicyd` 日志：
`Found game GameProcess("GameStubRunner", labelReason=LSSupportsGameMode (Info.plist))`
→ 全屏 → `Game mode status is now on.`

**HMCL 全自动接入（Minecraft 本体进游戏模式）**：

1. 启动 HMCL —— 面板列表会出现带「裸程序」徽标的 `java` 条目（HMCL 本体）
2. 选中它 → 点「开启游戏模式支持」—— 工具自动完成全部接线：
   生成带游戏声明的包装器替身，并把 HMCL 所有游戏实例的包装命令指向它（原配置备份为
   `.gmhelper-bak`，可随时还原）
3. **照常从 HMCL 启动游戏**：HMCL 实际经由包装器启动 java，游戏天生带游戏身份
4. 游戏切到**原生全屏**（⌃⌘F 或窗口绿色按钮）→ 游戏模式自动开启；按 ⌘Esc 可查看状态

说明：包装器以游戏身份注册后把进程镜像替换（execv）为真实 java，PID 不变、身份继承。
包装器注册身份约需 0.5 秒（HMCL 探测 Java 会略慢，正常）。**当前正在运行的游戏本局**
不受影响，重启游戏后生效。游戏内"全屏"若是无边框模式，请改用系统原生全屏，否则不会触发。
不需要时：选中该 java 条目点「还原默认」即可自动恢复所有实例的原配置。

## 6. 还原（关闭某个 App 的游戏模式支持）

1. 面板中选中该 App（状态显示「已具备游戏模式资格」）
2. 点 **「还原默认」**——从备份恢复原始 `Info.plist` 并重签
3. 重启该 App 后完全回到从前

> 首次开启时工具会自动备份原始 `Info.plist` 到
> `~/Library/Application Support/GameModeHelper/backups/<bundleID>/`，
> 还原就是从这份备份恢复，所以永远可逆。

## 7. 状态徽标说明

| 徽标 | 含义 |
|---|---|
| 「前台」 | 你正在使用的 App（通常就是游戏），已自动选中 |
| 「系统卷」 | SIP 保护的系统自带 App（如 Safari），无法修改，按钮会被拒绝 |
| 已具备游戏模式资格 / 还没有游戏模式声明 | 该 App 当前是否带游戏模式声明 |

## 8. 命令行用法

所有功能都有命令行等价物（便于脚本化）：

```bash
BIN=~/Applications/GameModeHelper.app/Contents/MacOS/GameModeHelper
$BIN --list                          # 列出已安装 App 及状态
$BIN --enable "/Applications/X.app"  # 开启
$BIN --disable "/Applications/X.app" # 还原
$BIN --status com.example.x          # 按 bundleID 查状态
$BIN --restart com.example.x         # 重启该 App
$BIN --selftest                      # 内置自检
$BIN --auth-test                     # 授权缓存诊断
```

## 9. 故障排查

**Q：全屏了但没有游戏模式？**
① 确认点过「重启 App 生效」；② 确认是原生全屏（⌃⌘F）而不是无边框窗口；③
状态是否显示「已具备游戏模式资格」；④ 看日志里有没有 `Found game` 记录：

```bash
grep "Found game" ~/Library/Logs/GameModeHelper/helper.log
/usr/bin/log show --last 10m --predicate 'process == "gamepolicyd"' --info | grep "Found game"
```

**Q：开启时报错「管理员操作失败」？**
看日志最后一行（`~/Library/Logs/GameModeHelper/helper.log`）；常见原因是密码框被取消或
副本复制失败（磁盘满）。重试即可。

**Q：App Store 下载的游戏重签后会怎样？**
本地启动不受影响；App Store 的自动更新和商店验证会失效（下次更新建议先「还原默认」，
更新完再开启）。

**Q：重启 App 失败（显示「重启未完成」）？**
App 拒绝正常退出（有未保存内容弹窗等）。手动保存并退出它，再在面板里点
「选择 App…」选中后重新操作，或改用 `--restart` 命令（含 SIGTERM 兜底）。

**Q：想给还没启动的游戏提前开好？**
点「选择 App…」直接挑选 `.app` 文件即可，不需要游戏在运行。

## 10. 日志

- 位置：`~/Library/Logs/GameModeHelper/helper.log`（面板底部「打开日志」按钮直达）
- 记录：每次开启/还原的方式与结果、备份事件、授权事件、自检结果
- 提 Issue 时请附相关片段（注意打码路径中的个人信息）

## 11. 卸载

1. 先把开启过的 App 逐个「还原默认」（重要：备份随工具一起删）
2. 退出本工具：面板底部点「退出」（确认即可；也可用活动监视器）
3. 删除文件：

```bash
mv ~/Applications/GameModeHelper.app ~/.Trash/
rm -rf ~/Library/Application\ Support/GameModeHelper ~/Library/Logs/GameModeHelper
```

---

问题未解决？请到 GitHub 提 [Issue](https://github.com/OWNER/GameModeHelper/issues)，
附上系统版本、芯片、App 名称与日志片段。
