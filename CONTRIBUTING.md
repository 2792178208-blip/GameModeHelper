# 贡献指南 Contributing

感谢考虑为本项目做贡献！欢迎 Issue 和 Pull Request。

## 开发环境

- macOS 14+（建议 Apple Silicon）
- Xcode Command Line Tools（`xcode-select --install`）

## 构建与自测

```bash
git clone <仓库地址>
cd GameModeHelper
./build.sh           # 构建 GameModeHelper.app
./selftest.sh        # 内置自检 12 项 + 端到端 6 项，提交前必须全过
./build.sh install   # 安装到 ~/Applications（可选）
```

## 提交规范

- 一个 PR 聚焦一件事；改动描述写清楚「为什么改」
- 涉及行为的改动请同步更新 README 与 CHANGELOG（Unreleased 段）
- 提交信息使用中文或英文均可，祈使句（如「修复 xxx」/ "Fix xxx"）

## 代码约定

- Swift 文件内注释与 UI 文案使用中文（与现有风格保持一致）
- 不引入第三方依赖；仅使用系统框架
- 任何会修改用户 App 的逻辑必须保持现有安全纪律：
  1. 先备份后动手，且必须可一键还原
  2. 不退出、不强杀任何进程（重启必须在用户明确确认后）
  3. 所有失败路径写日志，给用户明确错误信息
  4. 自检必须覆盖新逻辑

## 报告问题

请附上：macOS 版本、芯片（Apple Silicon / Intel）、出问题的 App 名称与获取方式
（App Store / 官网 / CrossOver 等）、`~/Library/Logs/GameModeHelper/helper.log` 的相关片段。
