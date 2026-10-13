import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen2/src/provider/repo/bilibili_account.dart';
import 'package:listen2/src/provider/repo/bilibili_playlists.dart';
import 'package:listen2/src/provider/repo/playlist_names.dart';
import 'package:listen2/src/widget/add_bilibili_playlist.dart';
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

class _ImportSources extends BilibiliPlaylists {
  _ImportSources([this.initial = const {}]);
  final Map<String, String> initial;
  final calls = <List<String>>[];
  final removals = <String>[];
  @override
  Map<String, String> build() => initial;
  @override
  Future<void> add(String name, String mediaId) async {
    calls.add([name, mediaId]);
    state = {...state, name: mediaId};
    await ref.read(playlistNamesProvider.notifier).add(name);
  }

  @override
  Future<void> remove(String name) async {
    removals.add(name);
    state = {...state}..remove(name);
  }
}

class _Names extends PlaylistNames {
  _Names([this.initial = const ['favorite']]);
  final List<String> initial;
  @override
  Future<List<String>> build() async => initial;

  @override
  Future<void> add(String name) async {
    state = AsyncData([...await future, name]);
  }

  @override
  Future<void> delete(String name) async {
    final names = await future;
    await ref.read(bilibiliPlaylistsProvider.notifier).remove(name);
    state = AsyncData(names.where((value) => value != name).toList());
  }
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
    {String? trackId, double textScale = 1, _ImportSources? sources}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      bilibiliAccountClientProvider.overrideWithValue(client),
      bilibiliPlaylistsProvider.overrideWith(() => sources ?? _ImportSources()),
      playlistNamesProvider
          .overrideWith(() => _Names(['favorite', ...?sources?.initial.keys])),
    ],
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
      'account import returns the new playlist through the creation dialog',
      (tester) async {
    final client = _AccountClient(loggedIn: true);
    final sources = _ImportSources();
    String? selected;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          bilibiliAccountClientProvider.overrideWithValue(client),
          bilibiliPlaylistsProvider.overrideWith(() => sources),
          playlistNamesProvider.overrideWith(_Names.new),
        ],
        child: MaterialApp(
            theme: AppStyle.theme,
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                          onPressed: () async =>
                              selected = await showAddBilibiliPlaylist(context),
                          child: const Text('打开新增歌单'),
                        ))))));
    await tester.tap(find.text('打开新增歌单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('平台导入'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('从我的收藏夹选择'));
    await tester.tap(find.text('从我的收藏夹选择'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('常听'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关联'));
    await tester.pumpAndSettle();
    expect(sources.calls, [
      ['常听', '987123']
    ]);
    expect(selected, '常听');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BilibiliAccountPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings link icons update and unlink can preserve the playlist',
      (tester) async {
    final client = _AccountClient(loggedIn: true);
    final sources = _ImportSources();
    await _pump(tester, client, sources: sources, textScale: 1.6);
    expect(find.byTooltip('关联到应用歌单'), findsOneWidget);
    expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('关联到应用歌单'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '本地常听');
    await tester.tap(find.widgetWithText(FilledButton, '关联'));
    await tester.pumpAndSettle();
    expect(sources.calls, [
      ['本地常听', '987123']
    ]);
    expect(find.byTooltip('取消关联：本地常听'), findsOneWidget);
    expect(find.byIcon(Icons.link_off_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('取消关联：本地常听'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(sources.removals, isEmpty);
    await tester.tap(find.byTooltip('取消关联：本地常听'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '取消关联'));
    await tester.pumpAndSettle();
    expect(sources.state, isEmpty);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(BilibiliAccountPage)));
    expect(await container.read(playlistNamesProvider.future),
        ['favorite', '本地常听']);
    expect(find.byTooltip('关联到应用歌单'), findsOneWidget);
    expect(client.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'unlink identifies aliases by folder ID and removes only selection',
      (tester) async {
    final client = _AccountClient(loggedIn: true);
    final sources = _ImportSources({
      '通勤': '987123',
      '周末': '987123',
      '其他': '222',
    });
    await _pump(tester, client, sources: sources);
    await tester.tap(find.byTooltip('取消关联：通勤、周末'));
    await tester.pumpAndSettle();
    expect(find.text('选择要取消关联的歌单'), findsOneWidget);
    await tester.tap(find.text('周末'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保留为本地歌单'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '取消关联'));
    await tester.pumpAndSettle();
    expect(sources.state, {'通勤': '987123', '其他': '222'});
    final container = ProviderScope.containerOf(
        tester.element(find.byType(BilibiliAccountPage)));
    expect(await container.read(playlistNamesProvider.future),
        ['favorite', '通勤', '其他']);
    expect(find.byTooltip('取消关联：通勤'), findsOneWidget);
    expect(client.writes, 0);
    expect(tester.takeException(), isNull);
  });

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
    await tester.ensureVisible(find.byTooltip('新建 Bilibili 收藏夹'));
    await tester.tap(find.byTooltip('新建 Bilibili 收藏夹'));
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
    await tester.tap(find.byTooltip('退出登录'));
    await tester.pumpAndSettle();
    expect(find.text('获取登录二维码'), findsOneWidget);
    expect(find.text('常听'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
