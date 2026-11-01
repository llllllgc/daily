<p align="center">
  <img src="assets/branding/launcher-source.png" width="112" alt="Daily app icon">
</p>

<h1 align="center">Daily</h1>

<p align="center">一款安静、简洁、本地优先的 Android / iOS 日常事项提醒与记录应用。</p>

Daily 适合记录容易忘记但需要持续完成的小事，例如服药、补充维生素、滴眼液和运动。它以日历为入口，把每天的计划、完成情况与遗漏记录放在同一个界面中。

## 功能

- 日历查看：默认按周查看，可展开月历；左右滑动切换日期范围，保留所选日期与展开状态。
- 自定义频率：通过双滚轮设置“每几天、当天几次”，每次提醒时间仍可单独调整。
- 多次事项：同一事项可以设置多个提醒时间，并以子任务形式展开。
- 一键完成：事项从左向右动态填色，撤销时逆向收回；完成项按完成先后下沉，最早完成的保持在最底部。
- 勾选反馈：圆圈由内向外填满，轻微回弹时一笔画出勾号；支持中途撤销和减少动态效果。
- 本地提醒：通知提供“完成”和可选的“稍后提醒”操作。
- 周期设置：支持每天、按星期或从开始日期起每隔指定天数重复，并可设置结束日期。
- 药品库存：可记录数量、单位、每次用量、生产日期和有效期；按实际完成记录扣减，撤销时返还。
- 周期预警：可在周期结束前一个月或一周提醒。
- 本地优先：事项和完成记录仅保存在设备的 SQLite 数据库中。
- 提醒诊断：应用内可以检查通知渠道、后台运行状态和已调度提醒。
- 设置入口：日历和事项页右上角的齿轮可打开设置，底部仅保留两个主页面。
- 轻盈分组：新建事项按名称、分类和安排分组，库存、有效期等可选内容放在“更多设置”中。
- 圆角线性图标：用药、营养、护理、饮水、运动、作息、学习、其他八个分类，共 32 个图标，可单独更换具体图标。
- 主题颜色：在“设置 → 主题颜色”中选择苔绿、雾蓝、暖杏或灰紫，立即生效并在重启后保留。
- 提醒时间：可直接在日历或事项列表修改，保留已有完成记录和用量统计。

## 技术栈

- Flutter / Dart
- SQLite（`sqflite`）
- Android / iOS 本地通知（`flutter_local_notifications`）
- `timezone` 与 `flutter_timezone`

## 开始开发

### 环境要求

- Flutter stable（当前已验证 Flutter 3.47.8 / Dart 3.13.7）
- Android 开发需要 JDK 17 和 Android SDK
- iOS 开发需要 macOS、Xcode 和已安装的 iOS 模拟器运行时；工程最低支持 iOS 15.0

### 运行

```bash
flutter pub get
flutter run
```

### 在 iOS 模拟器运行

```bash
flutter doctor -v
flutter pub get
flutter devices
flutter run -d <iOS模拟器设备ID>
```

先从 Xcode 打开一个 iOS 模拟器。如果 `flutter devices` 中没有 iOS 模拟器，
在 Xcode 的 Settings → Components 中安装 iOS 运行时，再启动模拟器。

工程使用 Flutter 的 Swift Package Manager 集成本地通知、时区和 SQLite 插件，
插件注册及 `ios/Flutter/ephemeral/` 由 Flutter 自动生成，不应手工修改或提交。
项目没有使用 `build_runner`，无需运行额外的 Dart 代码生成命令。

验证不需要签名的模拟器构建：

```bash
flutter build ios --simulator --debug
```

### 在 iPhone 真机运行

1. 用 Xcode 打开 `ios/Runner.xcworkspace`。
2. 在 Runner → Signing & Capabilities 中选择自己的开发 Team，
   并将默认 Bundle Identifier `com.example.daily` 换成自己唯一的标识。
3. 连接并信任 iPhone，在设备上开启开发者模式。
4. 使用 `flutter devices` 获取设备 ID，然后运行 `flutter run -d <iPhone设备ID>`。

首次保存事项时会请求通知权限，也可以在应用的“设置 → 通知设置”中开启。
拒绝后点击提示中的“设置”可跳转系统设置。通过“发送测试提醒”检查横幅和声音，
长按通知可以看到“完成”和可选的“稍后提醒”操作。
真机签名与通知在锁屏、专注模式下的表现需要在自己的 iPhone 上确认。

iOS 最多保留 64 条待发送本地通知。本应用优先调度未来 31 天中最近的 60 条
（包含周期提醒），为稍后提醒预留空间；每次启动、回到前台或保存事项时补充队列。
队列耗尽后需要再次打开应用，才能继续安排后续提醒。
本地通知不需要开启 Push Notifications 或 Remote notifications 后台模式。

更新 iOS 图标与原生启动图（复用现有品牌素材，无额外依赖）：

```bash
swift tool/generate_ios_assets.swift
```

### 检查与测试

```bash
flutter analyze
flutter test
```

### 构建 Android APK

```bash
flutter build apk --release
```

构建产物位于 `build/app/outputs/flutter-apk/`。

Android 与 iOS 使用同一套 `lib/` 功能代码；主题、日历、库存和提醒交互的更新会同时用于两个平台。

推送到 `main` 或提交 Pull Request 后，GitHub Actions 会自动执行静态检查、全部测试和 Android release APK 构建。
也可以在 [Flutter checks](https://github.com/llllllgc/daily/actions/workflows/flutter.yml) 页面手动运行。
打开成功的运行记录，在 Artifacts 中下载 `daily-android-<提交 SHA>`，解压后即可获得 `app-release.apk`；产物保留 30 天。
当前 release 构建沿用工程的调试签名，适合安装验证；正式分发前需要配置自己的发布签名。

## 项目结构

```text
lib/
├── app.dart                           # 页面与界面组件
├── main.dart                          # 应用启动与依赖初始化
├── models.dart                        # 领域模型与存储接口
├── theme.dart                         # 主题配色与偏好设置
├── item_icons.dart                    # 事项分类与图标目录
├── widgets/                           # 交互动画与原生矢量图标
├── data/daily_database.dart            # SQLite 持久化
└── services/notification_service.dart  # 通知调度与动作处理

test/                                  # 模型、界面、通知与资源测试
assets/branding/                       # 品牌和启动页素材
tool/                                  # 图标生成工具
```

## 数据与隐私

Daily 不需要账号，也不会把事项或完成记录上传到服务器。卸载应用或清除应用数据会删除本地记录，请在操作前自行确认。

Android 端使用通知权限来发送事项提醒，并监听设备启动事件以支持系统重启后的提醒恢复。部分系统可能需要手动允许后台运行。

## 参与贡献

欢迎提交 Issue 和 Pull Request。开始修改前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 项目状态

支持 Android 和 iOS，包含核心记录、SQLite 持久化、本地通知、通知动作与周期提醒。

## 许可证

本项目采用 [MIT License](LICENSE) 开源。
