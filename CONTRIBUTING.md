# 参与贡献

感谢你愿意改进 Daily。

## 开始之前

1. 先在 Issue 中描述问题、使用场景或功能建议。
2. 对较大的界面或数据模型改动，建议先讨论方案再开始实现。
3. 不要提交真实用户数据、签名文件、密钥或本地环境配置。

## 本地开发

```bash
flutter pub get
flutter analyze
flutter test
```

提交 Pull Request 前，请确保静态检查和全部测试通过。

## 代码约定

- 遵循仓库中的 `analysis_options.yaml`。
- 使用 `dart format` 格式化修改过的 Dart 文件。
- 新功能或 Bug 修复应尽量附带覆盖对应行为的测试。
- 保持本地优先原则；引入联网、账号或遥测能力前必须先讨论。
- UI 修改应延续当前克制、低饱和、清晰分层的视觉语言。

## 提交说明

提交信息应简短描述结果，例如：

```text
fix: allow editing reminder time
feat: complete occurrence from notification action
```

Pull Request 中请说明修改内容、验证方式，以及涉及界面时的前后对比。
