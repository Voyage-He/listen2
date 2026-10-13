import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen2/src/provider/repo/bilibili_playlists.dart';
import 'package:listen2/src/widget/add_bilibili_playlist.dart';
import 'package:listen2/src/widget/app_style.dart';

class _Sources extends BilibiliPlaylists {
  final calls = <List<String>>[];
  @override
  Map<String, String> build() => {};
  @override
  Future<void> add(String name, String mediaId) async =>
      calls.add([name, mediaId]);
}

Future<void> _open(WidgetTester tester, _Sources sources,
    {bool localOnly = false, double scale = 1}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
      overrides: [bilibiliPlaylistsProvider.overrideWith(() => sources)],
      child: MaterialApp(
        theme: AppStyle.theme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () => showAddBilibiliPlaylist(context,
                          localOnly: localOnly),
                      child: const Text('打开'),
                    ))),
      )));
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

void main() {
  test(
      'favorite source accepts IDs and Bilibili links but rejects unrelated URLs',
      () {
    for (final input in [
      ' 12345 ',
      'https://space.bilibili.com/123/favlist?fid=12345&ftype=create',
      'https://www.bilibili.com/list/ml12345?spm_id_from=test',
      'https://www.bilibili.com/medialist/detail/ml12345',
    ]) {
      expect(parseBilibiliFavoriteId(input), '12345');
    }
    for (final input in [
      '',
      '0',
      'abc',
      'https://example.com/?fid=12345',
      'https://bilibili.com.example.com/?fid=12345',
      'https://space.bilibili.com/123/favlist?fid=0',
      'https://www.bilibili.com/video/BV1abc',
    ]) {
      expect(() => parseBilibiliFavoriteId(input), throwsFormatException);
    }
  });

  testWidgets(
      'switching source preserves names and local creation ignores hidden source',
      (tester) async {
    final sources = _Sources();
    await _open(tester, sources);
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('playlist-name')), '日常');
    await tester.tap(find.text('平台导入'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('playlist-import-source')), '12345');
    await tester.ensureVisible(find.text('本地创建'));
    await tester.tap(find.text('本地创建'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('playlist-name')))
            .controller!
            .text,
        '日常');
    expect(find.byKey(const ValueKey('playlist-import-source')), findsNothing);
    await tester.tap(find.text('创建本地歌单'));
    await tester.pumpAndSettle();
    expect(sources.calls, [
      ['日常', '']
    ]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'platform import requires a source and extracts the full ID from a pasted link',
      (tester) async {
    final sources = _Sources();
    await _open(tester, sources);
    await tester.tap(find.text('平台导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入收藏夹'));
    await tester.pumpAndSettle();
    expect(find.text('请输入收藏夹链接或 ID'), findsOneWidget);
    expect(sources.calls, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('playlist-import-source')),
        'https://space.bilibili.com/123/favlist?fid=12345');
    await tester.enterText(find.byKey(const ValueKey('playlist-name')), '收藏音乐');
    await tester.tap(find.text('导入收藏夹'));
    await tester.pumpAndSettle();
    expect(sources.calls, [
      ['收藏音乐', '12345']
    ]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local-only creation keeps the song-saving flow focused',
      (tester) async {
    final sources = _Sources();
    await _open(tester, sources, localOnly: true);
    expect(find.text('平台导入'), findsNothing);
    expect(find.text('从我的收藏夹选择'), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('创建本地歌单'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both modes remain scrollable with large text and the keyboard',
      (tester) async {
    final sources = _Sources();
    await _open(tester, sources, scale: 1.6);
    await tester.tap(find.text('平台导入'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('playlist-name')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('导入收藏夹'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
