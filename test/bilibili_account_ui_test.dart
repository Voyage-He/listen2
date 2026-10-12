import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen2/src/provider/repo/bilibili_account.dart';
import 'package:listen2/src/view/page/option/bilibili_account.page.dart';
import 'package:listen2/src/widget/app_style.dart';
import 'package:music_api/music_api.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _Store implements BilibiliSessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String _) async {}
  @override
  Future<void> delete() async {}
}

class _AccountClient extends BilibiliAccountClient {
  _AccountClient({bool loggedIn = false}) : super(_Store()) {
    if (loggedIn) user = const BilibiliUser(mid: 123, name: '测试用户');
  }
  BilibiliQrStatus status = BilibiliQrStatus.waiting;
  bool saved = false;
  bool failWrite = false;
  int polls = 0;
  int cancellations = 0;
  int writes = 0;
  String? createdTitle;
  bool? createdPrivate;
  @override
  Future<BilibiliUser?> getLoggedInUser() async => user;
  @override
  Future<BilibiliQrCode> generateQrCode() async => const BilibiliQrCode(
      url: 'https://passport.bilibili.com/scan?key=test', key: 'test-key');
  @override
  Future<BilibiliQrStatus> pollQrCode(String key) async {
    polls++;
    if (status == BilibiliQrStatus.confirmed) {
      user = const BilibiliUser(mid: 123, name: '测试用户');
    }
    return status;
  }

  @override
  void cancelQrLogin() {
    cancellations++;
    super.cancelQrLogin();
  }

  @override
  Future<int> getVideoAid(String bvid) async => 456;
  @override
  Future<List<BilibiliFavoriteFolder>> getFavoriteFolders({int? avid}) async =>
      [
        BilibiliFavoriteFolder(
            id: 987123,
            title: '常听',
            count: saved ? 1 : 0,
            isPrivate: true,
            containsVideo: saved),
      ];
  @override
  Future<void> setFavorite(int avid, int folderId,
      {required bool saved}) async {
    expect(avid, 456);
    expect(folderId, 987123);
    writes++;
    if (failWrite) throw const BilibiliApiException(-403, '收藏失败，请重试');
    this.saved = saved;
  }

  @override
  Future<void> createFavoriteFolder(String title,
      {bool isPrivate = true}) async {
    createdTitle = title;
    createdPrivate = isPrivate;
  }

  @override
  Future<void> logout() async => user = null;
}

Future<void> _pump(WidgetTester tester, _AccountClient client,
    {String? trackId, double textScale = 1}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [bilibiliAccountClientProvider.overrideWithValue(client)],
    child: MaterialApp(
      theme: AppStyle.theme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!),
      home: Scaffold(body: BilibiliAccountPage(trackId: trackId)),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'polling pauses in the background and QR expires after three minutes',
      (tester) async {
    final client = _AccountClient();
    await _pump(tester, client);
    await tester.tap(find.text('获取登录二维码'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 4));
    expect(client.polls, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(client.polls, 1);
    await tester.pump(const Duration(seconds: 181));
    await tester.pumpAndSettle();
    expect(find.text('二维码已过期，请刷新'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'QR flow shows scanned and expired states; refresh starts a new flow',
      (tester) async {
    final client = _AccountClient();
    await _pump(tester, client);
    await tester.tap(find.text('获取登录二维码'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    client.status = BilibiliQrStatus.scanned;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('已扫码，请在 Bilibili 中确认登录'), findsOneWidget);
    client.status = BilibiliQrStatus.expired;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('二维码已过期，请刷新'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await tester.ensureVisible(find.text('刷新二维码'));
    await tester.tap(find.text('刷新二维码'));
    await tester.pumpAndSettle();
    client.status = BilibiliQrStatus.confirmed;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('测试用户'), findsOneWidget);
    expect(find.text('常听'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed writes keep favorite state and allow a successful retry',
      (tester) async {
    final client = _AccountClient(loggedIn: true)..failWrite = true;
    await _pump(tester, client, trackId: '1abc');
    await tester.tap(find.text('常听'));
    await tester.pumpAndSettle();
    expect(find.text('收藏失败，请重试'), findsOneWidget);
    expect(find.textContaining('已收藏'), findsNothing);
    client.failWrite = false;
    await tester.tap(find.text('常听'));
    await tester.pumpAndSettle();
    expect(find.textContaining('· 已收藏'), findsOneWidget);
    await tester.tap(find.text('常听'));
    await tester.pumpAndSettle();
    expect(find.textContaining('· 已收藏'), findsNothing);
    expect(client.writes, 3);
    expect(find.text('已从 Bilibili 收藏夹移除'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'new folders validate names and default to private on a narrow screen',
      (tester) async {
    final client = _AccountClient(loggedIn: true);
    await _pump(tester, client, textScale: 1.6);
    await tester.ensureVisible(find.text('新建 Bilibili 收藏夹'));
    await tester.tap(find.text('新建 Bilibili 收藏夹'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(find.text('请输入名称'), findsOneWidget);
    expect(client.createdTitle, isNull);
    await tester.enterText(find.byType(TextFormField), '音乐');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(client.createdTitle, '音乐');
    expect(client.createdPrivate, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving login cancels QR polling', (tester) async {
    final client = _AccountClient();
    await _pump(tester, client);
    await tester.tap(find.text('获取登录二维码'));
    await tester.pumpAndSettle();
    final cancellations = client.cancellations;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
    expect(client.cancellations, cancellations + 1);
    expect(client.polls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout returns to login without showing old folders',
      (tester) async {
    final client = _AccountClient(loggedIn: true);
    await _pump(tester, client);
    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();
    expect(find.text('获取登录二维码'), findsOneWidget);
    expect(find.text('常听'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
