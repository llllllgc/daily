# Daily 开发约定

- 每次修改 Daily 后，将最新本地代码更新到 Device Hub 的 iPhone 17 模拟器。
- 优先使用 Flutter 热重载；必要时热重启或重新编译。修改完成后保持调试会话运行。
- 不自动上传或推送到 GitHub；只有用户明确要求上传时才执行。
- 调试会话信息保存在 `.dart_tool/daily-device-session.json`。恢复会话前确认进程仍在运行且属于本项目，避免控制其他项目的调试会话。
