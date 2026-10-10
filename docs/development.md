# 开发与构建指南

Flutter 音乐播放器，支持 Android、iOS 和 Windows。项目使用 Flutter **3.24.1**（见 `.fvmrc`）。

## 初始化

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
```

仓库不提交 `*.g.dart`，首次运行或修改 Riverpod / Hive 模型后都需要执行代码生成。

## 运行 iOS

需要 macOS、完整 Xcode（仅 Command Line Tools 不够）、Xcode 的 iOS SDK / 模拟器，以及 CocoaPods。

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
flutter doctor -v
flutter pub get
dart run build_runner build --delete-conflicting-outputs
cd ios
pod install
cd ..
flutter devices
flutter run -d <iPhone或模拟器ID>
```

最低 iOS 版本为 **12.0**。工程启用了后台音频；播放器配置为音乐播放会话，并向锁屏 / 控制中心同步歌曲、时长、进度以及播放、暂停、停止、拖动进度操作。来电等中断会暂停播放；只有系统允许恢复的暂停中断结束后才自动恢复，耳机拔出会暂停。

音频数据仍存储在应用沙盒内。iOS 播放前会将缓存的 AAC 数据写入临时 `.m4a` 文件，交给 AVPlayer 播放。备份通过系统“文件”选择器导入 / 导出，沿用 Android 的 `listen2.back` JSON 格式。网络 API 使用 HTTPS，不开放全局明文网络权限。

## 真机签名与打包

打开 `ios/Runner.xcworkspace`，在 Runner → Signing & Capabilities 中选择自己的开发团队，并将默认 `com.example.listen2` Bundle Identifier 改为自己的唯一标识。仓库不包含开发团队、证书或描述文件。

```sh
# 检查无需签名的设备构建
flutter build ios --no-codesign
# 配置签名后打包
flutter build ipa
```

## iOS 验收

建议在真机 Release 模式测试以下流程：

- 搜索、收藏、播放歌曲，重启后恢复收藏与播放列表。
- 锁屏和切到后台后持续播放，歌曲结束后自动播放下一首。
- 在锁屏 / 控制中心播放、暂停和拖动进度，核对歌曲信息。
- 来电 / Siri 中断、手动暂停后结束中断、耳机断开。
- 导出备份至“文件”，再导入；取消操作和损坏备份不会覆盖收藏。

模拟器和 Dart 单元测试无法替代真机的后台播放、中断和签名验收。
