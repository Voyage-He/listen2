# 开发与构建指南

Flutter 音乐播放器，支持 Android、iOS 和 Windows。项目使用 Flutter **3.24.1**（见 `.fvmrc`）。

## 初始化

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
```

仓库不提交 `*.g.dart`，首次运行或修改 Riverpod / Hive 模型后都需要执行代码生成。

## Bilibili 登录与收藏夹

设置 → Bilibili 账号与收藏夹 → 获取登录二维码，用 Bilibili 手机客户端扫码确认。歌曲收藏面板的 Bilibili 图标打开该歌曲的平台收藏状态，可直接添加或移除；账号页面支持新建收藏夹和导入自己的私密收藏夹。

导入歌单在列表与详情显示 Bilibili logo（复用 API 文档仓库的 SVG）。歌曲收藏面板也列出导入的收藏夹：添加/取消收藏会先校验登录与收藏夹归属，再写入平台；成功后更新该收藏夹的所有本地导入副本并刷新内容。未登录时可扫码后继续原操作，其他账号的收藏夹仅可查看。收藏写入期间收到的旧刷新结果不会覆盖新状态。

接口依据本地 `bilibili-API-collect` 的 `docs/login/login_action/QR.md`、`docs/login/login_info.md`、`docs/login/exit.md`、`docs/fav/info.md`、`docs/fav/action.md` 和 `docs/video/action.md`。网页扫码轮询的四种状态均有处理，登录成功后通过 `/x/web-interface/nav` 校验身份，收藏写入携带 `bili_jct` 的 CSRF 值。

2026-10-12 实测公共二维码生成接口返回的扫码地址使用 `account.bilibili.com`；实现同时接受这个域名和文档中的 `passport.bilibili.com`，只接受 HTTPS。

登录 Cookie 和 refresh token 由 `flutter_secure_storage` 单独保存，iOS 使用 Keychain，Android 使用加密 SharedPreferences，Windows 使用插件的系统加密存储。Android 已禁用应用自动备份以避免加密凭据和设备密钥被分别恢复；应用内收藏导出仍可使用。匿名访客 Cookie 沿用原来的 Hive 缓存。当前保留 refresh token 但尚未接入 `cookie_refresh.md` 的自动续期，登录过期时重新扫码。

接口和 UI 测试不使用真实账号。真机验收需检查：扫码等待/确认/超时、切到 Bilibili 后返回、重启恢复、私密收藏夹导入、创建公开/私密收藏夹、收藏/取消收藏，以及退出后重启。二维码需要手机客户端扫描，可在另一台设备上展示。

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

### 当前环境的模拟器渲染兼容处理

2026-10-14 的多份模拟器崩溃报告显示：宿主 `SimMetalHost` 在 `MTLSimApplicationContext::newObjectCommand_DEPRECATED` / `newCommandQueueWithDescriptor` 中发生 `EXC_BAD_ACCESS`，随后 Runner 的 `io.flutter.1.raster` 线程因 Metal XPC 连接丢失而终止。另有后台切换时等待 GPU 锁的 watchdog 记录。当前日志定位到模拟器的原生渲染服务。

在项目固定的 Flutter 3.24.1 下，使用专用脚本启动模拟器，以 Skia 软件渲染避开该服务：

```sh
# 只有一个已启动的 iOS 模拟器时自动选择
bash scripts/run_ios_simulator.sh
# 或指定模拟器 UDID
bash scripts/run_ios_simulator.sh <模拟器UDID>
```

脚本同时传入 `--no-enable-impeller` 和 `--enable-software-rendering`，并校验目标为 iOS 模拟器。它不修改真机或 Release 的渲染配置。软件渲染的动画性能可能低于 GPU 渲染。上述参数属于启动参数，重新从桌面图标冷启动不会保留；在当前环境里重新运行时也应使用该脚本。单独禁用 Impeller 仍可能使用 Metal，不能完全绕开失效的宿主渲染服务。

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
