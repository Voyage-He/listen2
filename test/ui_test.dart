import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen2/src/provider/global/player.dart' as player;
import 'package:listen2/src/provider/repo/playlist_names.dart';
import 'package:listen2/src/provider/repo/bilibili_playlists.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:listen2/src/provider/global/current_playlist.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/view/page/home/home.page.dart';
import 'package:listen2/src/view/page/player/player.page.dart';
import 'package:listen2/src/view/page/playlist/playlist.dart';
import 'package:listen2/src/view/page/search/search.page.dart';
import 'package:listen2/src/widget/app_style.dart';
import 'package:listen2/src/widget/progress_bar.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';
import 'package:listen2/src/widget/player_tutorial.dart';
import 'package:listen2/src/widget/playlist_picker.dart';
import 'package:listen2/src/widget/bilibili_logo.dart';
import 'package:listen2/main.dart' show ListenApp;
import 'package:listen2/src/provider/global/main.dart';
import 'package:listen2/src/provider/global/background_settings.dart';
import 'package:listen2/src/provider/global/playback_settings.dart';

class _PlaybackSettings extends PlaybackSettingsNotifier {
  @override
  bool build() => true;
}

class _BackgroundSettings extends BackgroundSettingsNotifier {
  int saves = 0;
  @override
  BackgroundSettings build() => const BackgroundSettings();
  @override
  Future<void> save() async {
    saves++;
  }
}

class _Names extends PlaylistNames {
  @override
  Future<List<String>> build() async => ['favorite', '一个很长很长的歌单名称，用来验证小屏幕布局'];
}

class _Ids extends PlaylistIdsNotifier {
  @override
  List<String> build(String playlistName) => [];
}

class _PlaylistSearchIds extends PlaylistIdsNotifier {
  @override
  List<String> build(String playlistName) => ['first', 'second', 'third'];
}

class _WritableIds extends _Ids {
  @override
  Future<void> add(String id) async {
    if (!state.contains(id)) state = [...state, id];
  }

  @override
  Future<void> delete(String id) async {
    state = state.where((value) => value != id).toList();
  }
}

class _RemovingIds extends _WritableIds {
  int calls = 0;
  bool fail = false;
  Completer<void>? pending;

  @override
  List<String> build(String playlistName) => ['one', 'two'];

  @override
  Future<void> delete(String id) async {
    calls++;
    if (pending != null) await pending!.future;
    if (fail) throw StateError('storage unavailable');
    await super.delete(id);
  }
}

class _SavingIds extends _WritableIds {
  int calls = 0;
  bool fail = false;
  Completer<void>? pending;

  @override
  Future<void> add(String id) async {
    calls++;
    if (pending != null) await pending!.future;
    if (fail) throw StateError('storage unavailable');
    await super.add(id);
  }
}

class _CollectionNames extends PlaylistNames {
  @override
  Future<List<String>> build() async => ['favorite', '日常', 'Bili 歌单'];
}

class _CollectionSources extends _Sources {
  @override
  Map<String, String> build() => {'Bili 歌单': '12345'};
}

class _UnlinkSources extends _Sources {
  @override
  Map<String, String> build() => {'常听': '12345'};

  @override
  Future<void> remove(String name) async {
    state = {...state}..remove(name);
  }
}

class _UnlinkNames extends PlaylistNames {
  @override
  Future<List<String>> build() async => ['favorite', '常听'];

  @override
  Future<void> delete(String name) async {
    await ref.read(bilibiliPlaylistsProvider.notifier).remove(name);
    state =
        AsyncData(state.requireValue.where((value) => value != name).toList());
  }
}

class _MutableCollectionNames extends PlaylistNames {
  @override
  Future<List<String>> build() async => ['favorite', '日常'];

  @override
  Future<void> add(String name) async {
    state = AsyncData([...state.requireValue, name]);
  }
}

class _CreatingSources extends _Sources {
  @override
  Future<void> add(String name, String mediaId) async {
    await ref.read(playlistNamesProvider.notifier).add(name);
  }
}

class _Sources extends BilibiliPlaylists {
  @override
  Map<String, String> build() => {};
}

class _ImportSources extends _Sources {
  final attempts = <List<String>>[];
  Completer<void>? pending;

  @override
  Future<void> add(String name, String mediaId) async {
    attempts.add([name, mediaId]);
    if (pending != null) await pending!.future;
  }
}

class _Player extends player.PlayerStateNotifier {
  @override
  player.PlayerState build() => player.PlayerState();

  void select(Track? track) => state = player.PlayerState(track: track);
}

final _singleTrack = Track('one', 'Test record', 'Artist', '');

class _SingleTrackPlayer extends player.PlayerStateNotifier {
  @override
  player.PlayerState build() => player.PlayerState(track: _singleTrack);
}

class _SeekingPlayer extends player.PlayerStateNotifier {
  _SeekingPlayer(this.playbackState);
  final ap.PlayerState playbackState;
  final pending = Completer<void>();
  Duration? target;

  @override
  player.PlayerState build() => player.PlayerState(
      state: playbackState,
      track: _singleTrack,
      now: const Duration(seconds: 45),
      length: const Duration(minutes: 3));

  void updatePosition(Duration position) =>
      state = state.copyWith(now: position);

  @override
  Future<void> seek(Duration position) async {
    target = position;
    await pending.future;
    updatePosition(position);
  }
}

class _SingleTrackQueue extends CurrentPlaylistNotifier {
  @override
  CurrentPlaylistState build() =>
      const CurrentPlaylistState(index: 0, playlist: ['one']);
}

class _ShelfQueue extends _SearchQueue {
  _ShelfQueue(this.ids);
  final List<String> ids;

  @override
  CurrentPlaylistState build() => CurrentPlaylistState(index: 0, playlist: ids);
}

class _SearchResults extends SearchResult {
  _SearchResults(this.tracks);
  final List<Track> tracks;

  @override
  Future<List<Track>> build() async => tracks;
}

class _SearchQueue extends CurrentPlaylistNotifier {
  String? playedId;

  @override
  CurrentPlaylistState build() =>
      const CurrentPlaylistState(index: 0, playlist: ['old']);

  @override
  Future<void> play(String trackId, List<String> playlistTrackIds,
      {bool autoplay = true}) async {
    playedId = trackId;
    state = CurrentPlaylistState(
        index: playlistTrackIds.indexOf(trackId),
        playlist: List.of(playlistTrackIds));
  }
}

void main() {
  ProviderContainer unlinkContainer() => ProviderContainer(overrides: [
        bilibiliPlaylistsProvider.overrideWith(_UnlinkSources.new),
        playlistNamesProvider.overrideWith(_UnlinkNames.new),
        playlistIdsNotifierProvider('常听').overrideWith(_PlaylistSearchIds.new),
        playlistTracksProvider('常听').overrideWith((ref) async => [
              Track('first', 'Song first', 'Artist', ''),
              Track('second', 'Song second', 'Artist', ''),
            ]),
      ]);

  testWidgets('unlink can be canceled or confirmed while keeping the playlist',
      (tester) async {
    final container = unlinkContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppStyle.theme,
            home: const Scaffold(body: PlaylistPage(playlistName: '常听')))));
    await tester.pumpAndSettle();
    expect(find.byType(BilibiliLogo), findsOneWidget);
    await tester.tap(find.byTooltip('取消 Bilibili 关联'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(container.read(bilibiliPlaylistsProvider), {'常听': '12345'});
    await tester.tap(find.byTooltip('取消 Bilibili 关联'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue);
    await tester.tap(find.widgetWithText(FilledButton, '取消关联'));
    await tester.pumpAndSettle();
    expect(container.read(bilibiliPlaylistsProvider), isEmpty);
    expect(find.byType(BilibiliLogo), findsNothing);
    expect(find.text('Song first'), findsOneWidget);
    expect(
        await container.read(playlistNamesProvider.future), ['favorite', '常听']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'unlink can remove the app playlist on a narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = unlinkContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppStyle.theme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!),
            home: const Scaffold(body: PlaylistPage(playlistName: '常听')))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('取消 Bilibili 关联'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保留为本地歌单'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);
    await tester.tap(find.widgetWithText(FilledButton, '取消关联'));
    await tester.pumpAndSettle();
    expect(container.read(bilibiliPlaylistsProvider), isEmpty);
    expect(await container.read(playlistNamesProvider.future), ['favorite']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'playlist search filters locally and preserves the playback queue',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final queue = _SearchQueue();
    var loads = 0;
    final container = ProviderContainer(overrides: [
      bilibiliPlaylistsProvider.overrideWith(_Sources.new),
      playlistNamesProvider.overrideWith(_Names.new),
      playlistIdsNotifierProvider('favorite')
          .overrideWith(_PlaylistSearchIds.new),
      currentPlaylistNotifierProvider.overrideWith(() => queue),
      playlistTracksProvider('favorite').overrideWith((ref) async {
        loads++;
        return [
          Track('first', '夜曲', '周杰伦', ''),
          Track('second', 'Hello', 'Adele', ''),
          Track('third', '晴天', '周杰伦', ''),
        ];
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          theme: AppStyle.theme,
          home: const Scaffold(body: PlaylistPage(playlistName: 'favorite'))),
    ));
    await tester.pumpAndSettle();
    final search = find.byType(TextField);
    await tester.enterText(search, ' 周杰伦 ');
    await tester.pumpAndSettle();
    expect(find.text('夜曲'), findsOneWidget);
    expect(find.text('晴天'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);
    expect(find.text('2 / 3 首歌曲'), findsOneWidget);
    await tester.tap(find.byTooltip('倒序排列'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('晴天')).dy,
        lessThan(tester.getTopLeft(find.text('夜曲')).dy));
    await tester.enterText(search, 'hELLo');
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('夜曲'), findsNothing);
    await tester.tap(find.text('Hello'));
    await tester.pumpAndSettle();
    expect(queue.playedId, 'second');
    expect(queue.state.playlist, ['first', 'second', 'third']);
    await tester.enterText(search, '找不到');
    await tester.pumpAndSettle();
    expect(find.text('没有找到匹配的歌曲'), findsOneWidget);
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('夜曲'), findsOneWidget);
    expect(find.text('晴天'), findsOneWidget);
    expect(loads, 1);
  });

  testWidgets('settings preview and player background follow both sliders',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = _BackgroundSettings();
    final container = ProviderContainer(overrides: [
      backgroundSettingsProvider.overrideWith(() => settings),
      autoplayOnStartupProvider.overrideWith(_PlaybackSettings.new),
      globalReadyProvider.overrideWith((ref) async {}),
      player.playerStateNotifierProvider.overrideWith(_SingleTrackPlayer.new),
      currentPlaylistNotifierProvider.overrideWith(_SingleTrackQueue.new),
      playlistIdsNotifierProvider('favorite').overrideWith(_Ids.new),
      trackCoverProvider(_singleTrack).overrideWith((ref) async =>
          base64Decode('R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==')),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const ListenApp()));
    await tester.pumpAndSettle();
    await tester.drag(find.text('LISTEN 2'), const Offset(120, 0));
    await tester.pumpAndSettle();
    final blur = find.byKey(const ValueKey('background-blur-slider'));
    final gradient = find.byKey(const ValueKey('background-gradient-slider'));
    await tester.ensureVisible(blur);
    await tester.drag(blur, const Offset(180, 0));
    await tester.pumpAndSettle();
    final saved = container.read(backgroundSettingsProvider);
    expect(saved.blur, BackgroundSettings.maxBlur);
    expect(tester.widget<ImageFiltered>(find.byType(ImageFiltered)).imageFilter,
        ImageFilter.blur(sigmaX: saved.blur, sigmaY: saved.blur));
    await tester.ensureVisible(gradient);
    await tester.drag(gradient, const Offset(-220, 0));
    await tester.pumpAndSettle();
    expect(container.read(backgroundSettingsProvider).gradient, 0);
    List<Color> colors() => (tester
            .widget<DecoratedBox>(
                find.byKey(const ValueKey('background-gradient')))
            .decoration as BoxDecoration)
        .gradient!
        .colors;
    expect(colors().every((color) => color.alpha == 0), isTrue);
    expect(settings.saves, 2);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(Player), findsOneWidget);
    expect(tester.widget<ImageFiltered>(find.byType(ImageFiltered)).imageFilter,
        ImageFilter.blur(sigmaX: saved.blur, sigmaY: saved.blur));
    expect(colors().every((color) => color.alpha == 0), isTrue);
    settings.setBlur(0);
    await tester.pump();
    expect(tester.widget<ImageFiltered>(find.byType(ImageFiltered)).enabled,
        isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('background fills system bar areas while controls stay safe',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: [
      backgroundSettingsProvider.overrideWith(_BackgroundSettings.new),
      autoplayOnStartupProvider.overrideWith(_PlaybackSettings.new),
      globalReadyProvider.overrideWith((ref) async {}),
      player.playerStateNotifierProvider.overrideWith(_SingleTrackPlayer.new),
      currentPlaylistNotifierProvider.overrideWith(_SingleTrackQueue.new),
      playlistIdsNotifierProvider('favorite').overrideWith(_Ids.new),
      trackCoverProvider(_singleTrack).overrideWith((ref) async =>
          base64Decode('R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==')),
    ], child: const ListenApp()));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(Player)),
        const Rect.fromLTWH(0, 0, 390, 844));
    expect(tester.getRect(find.byType(ImageFiltered)),
        const Rect.fromLTWH(0, 0, 390, 844));
    expect(tester.getRect(find.text('LISTEN 2')).top, greaterThanOrEqualTo(59));
    expect(tester.getRect(find.byType(SingleChildScrollView)).bottom,
        lessThanOrEqualTo(810));

    await tester.drag(find.text('LISTEN 2'), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(PageSurface)),
        const Rect.fromLTWH(0, 0, 390, 844));
    expect(tester.getRect(find.byTooltip('返回')).top, greaterThanOrEqualTo(59));
    expect(
        tester.getRect(find.byType(ListView)).bottom, lessThanOrEqualTo(810));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'collection picker stays open for multiple additions and removals',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final favorite = _WritableIds();
    final daily = _WritableIds();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          backgroundSettingsProvider.overrideWith(_BackgroundSettings.new),
          player.playerStateNotifierProvider
              .overrideWith(_SingleTrackPlayer.new),
          currentPlaylistNotifierProvider.overrideWith(_SingleTrackQueue.new),
          playlistNamesProvider.overrideWith(_CollectionNames.new),
          bilibiliPlaylistsProvider.overrideWith(_CollectionSources.new),
          playlistIdsNotifierProvider('favorite').overrideWith(() => favorite),
          playlistIdsNotifierProvider('日常').overrideWith(() => daily),
          playlistIdsNotifierProvider('Bili 歌单').overrideWith(_Ids.new),
          trackCoverProvider(_singleTrack)
              .overrideWith((ref) async => throw StateError('no cover')),
        ],
        child: MaterialApp(
            theme: AppStyle.theme,
            home: const Scaffold(body: Player(isHome: true)))));
    await tester.pumpAndSettle();
    expect(find.byTooltip('收藏'), findsNothing);
    final record = find.byKey(const ValueKey('vinyl-record'));
    Future<void> openCollection() async {
      await tester.drag(record, const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(find.text('收藏到歌单'), findsOneWidget);
      expect(find.text('我喜欢的'), findsOneWidget);
      expect(find.text('日常'), findsOneWidget);
      expect(find.text('Bili 歌单'), findsOneWidget);
      expect(find.byType(BilibiliLogo), findsNWidgets(2));
    }

    await openCollection();
    await tester.tap(find.text('我喜欢的'));
    await tester.pumpAndSettle();
    expect(favorite.state, ['one']);
    expect(find.text('收藏到歌单'), findsOneWidget);
    expect(find.text('已收藏到「我喜欢的」'), findsOneWidget);
    expect(find.text('1 首歌曲 · 已收藏'), findsOneWidget);
    await tester.tap(find.text('日常'));
    await tester.pumpAndSettle();
    expect(daily.state, ['one']);
    expect(favorite.state, ['one']);
    expect(find.text('收藏到歌单'), findsOneWidget);
    expect(find.text('1 首歌曲 · 已收藏'), findsNWidgets(2));
    expect(find.text('已收藏到「日常」'), findsOneWidget);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(Player)));
    final playback = container.read(player.playerStateNotifierProvider);
    final favoriteRow =
        find.ancestor(of: find.text('我喜欢的'), matching: find.byType(ListTile));
    await tester.tap(
        find.descendant(of: favoriteRow, matching: find.byTooltip('取消收藏')));
    await tester.pumpAndSettle();
    expect(favorite.state, isEmpty);
    expect(daily.state, ['one']);
    expect(find.text('收藏到歌单'), findsOneWidget);
    expect(find.text('已从「我喜欢的」移除'), findsOneWidget);
    expect(find.text('1 首歌曲 · 已收藏'), findsOneWidget);
    expect(container.read(player.playerStateNotifierProvider), same(playback));
    await tester.tap(find.text('我喜欢的'));
    await tester.pumpAndSettle();
    expect(favorite.state, ['one']);
    expect(find.text('收藏到歌单'), findsOneWidget);
    expect(find.text('1 首歌曲 · 已收藏'), findsNWidgets(2));
    expect(find.byType(PlaylistPage), findsNothing);
    await tester.tap(find.text('日常'));
    await tester.pumpAndSettle();
    expect(daily.state, isEmpty);
    expect(favorite.state, ['one']);
    expect(find.text('已从「日常」移除'), findsOneWidget);
    await tester.tap(find.byTooltip('添加歌单'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('取消')));
    await tester.pumpAndSettle();
    expect(find.text('收藏到歌单'), findsOneWidget);
    await tester.tapAt(const Offset(8, 80));
    await tester.pumpAndSettle();
    expect(find.text('收藏到歌单'), findsNothing);
    expect(container.read(player.playerStateNotifierProvider), same(playback));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed addition stays open and can be retried', (tester) async {
    final ids = _SavingIds()
      ..fail = true
      ..pending = Completer<void>();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          playlistNamesProvider.overrideWith(_CollectionNames.new),
          bilibiliPlaylistsProvider.overrideWith(_CollectionSources.new),
          playlistIdsNotifierProvider('favorite').overrideWith(() => ids),
          playlistIdsNotifierProvider('日常').overrideWith(_Ids.new),
          playlistIdsNotifierProvider('Bili 歌单').overrideWith(_Ids.new),
        ],
        child: MaterialApp(
            theme: AppStyle.theme,
            home: const Scaffold(body: PlaylistPicker(trackId: 'one')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我喜欢的'));
    await tester.pump();
    expect(ids.calls, 1);
    await tester.tap(find.text('我喜欢的'));
    await tester.pump();
    expect(ids.calls, 1);
    ids.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('收藏失败，请重试'), findsOneWidget);
    expect(find.text('收藏到歌单'), findsOneWidget);
    expect(find.byTooltip('取消收藏'), findsNothing);
    expect(ids.state, isEmpty);
    ids
      ..fail = false
      ..pending = null;
    await tester.tap(find.text('我喜欢的'));
    await tester.pumpAndSettle();
    expect(ids.calls, 2);
    expect(ids.state, ['one']);
    expect(find.text('收藏到歌单'), findsOneWidget);
    expect(find.text('1 首歌曲 · 已收藏'), findsOneWidget);
    expect(find.text('已收藏到「我喜欢的」'), findsOneWidget);
    expect(find.text('收藏失败，请重试'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new playlist collects the song and keeps the picker open',
      (tester) async {
    final created = _WritableIds();
    final favorite = _WritableIds();
    final daily = _WritableIds();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          playlistNamesProvider.overrideWith(_MutableCollectionNames.new),
          bilibiliPlaylistsProvider.overrideWith(_CreatingSources.new),
          playlistIdsNotifierProvider('favorite').overrideWith(() => favorite),
          playlistIdsNotifierProvider('日常').overrideWith(() => daily),
          playlistIdsNotifierProvider('新歌单').overrideWith(() => created),
        ],
        child: MaterialApp(
            theme: AppStyle.theme,
            home: const Scaffold(body: PlaylistPicker(trackId: 'one')))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加歌单'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '新歌单');
    await tester.tap(find.text('创建本地歌单'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('收藏到歌单'), findsOneWidget);
    expect(find.text('新歌单'), findsOneWidget);
    expect(find.text('已收藏到「新歌单」'), findsOneWidget);
    expect(created.state, ['one']);
    await tester.tap(find.text('我喜欢的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日常'));
    await tester.pumpAndSettle();
    expect(find.text('收藏到歌单'), findsOneWidget);
    expect(favorite.state, ['one']);
    expect(daily.state, ['one']);
    expect(created.state, ['one']);
    expect(find.byTooltip('取消收藏'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed removal stays saved and prevents duplicate requests',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ids = _RemovingIds()
      ..fail = true
      ..pending = Completer<void>();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          playlistNamesProvider.overrideWith(_CollectionNames.new),
          bilibiliPlaylistsProvider.overrideWith(_CollectionSources.new),
          playlistIdsNotifierProvider('favorite').overrideWith(() => ids),
          playlistIdsNotifierProvider('日常').overrideWith(_Ids.new),
          playlistIdsNotifierProvider('Bili 歌单').overrideWith(_Ids.new),
        ],
        child: MaterialApp(
            theme: AppStyle.theme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!),
            home: const Scaffold(body: PlaylistPicker(trackId: 'one')))));
    await tester.pumpAndSettle();
    expect(find.text('Bili 歌单'), findsOneWidget);
    await tester.tap(find.byTooltip('取消收藏'));
    await tester.pump();
    expect(ids.calls, 1);
    expect(ids.state, ['one', 'two']);
    await tester.tap(find.text('我喜欢的'));
    await tester.pump();
    expect(ids.calls, 1);
    ids.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('取消收藏失败，请重试'), findsOneWidget);
    expect(ids.state, ['one', 'two']);
    expect(find.text('2 首歌曲 · 已收藏'), findsOneWidget);
    ids
      ..fail = false
      ..pending = null;
    await tester.tap(find.byTooltip('取消收藏'));
    await tester.pumpAndSettle();
    expect(ids.calls, 2);
    expect(ids.state, ['two']);
    expect(find.text('1 首歌曲'), findsOneWidget);
    expect(find.text('已从「我喜欢的」移除'), findsOneWidget);
    expect(find.byTooltip('取消收藏'), findsNothing);
    expect(find.text('取消收藏失败，请重试'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final playbackState in [ap.PlayerState.playing, ap.PlayerState.paused]) {
    testWidgets('tonearm stays stable while seeking in $playbackState',
        (tester) async {
      final playback = _SeekingPlayer(playbackState);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            backgroundSettingsProvider.overrideWith(_BackgroundSettings.new),
            player.playerStateNotifierProvider.overrideWith(() => playback),
            currentPlaylistNotifierProvider.overrideWith(_SingleTrackQueue.new),
            playlistIdsNotifierProvider('favorite').overrideWith(_Ids.new),
            trackCoverProvider(_singleTrack)
                .overrideWith((ref) async => throw StateError('no cover')),
          ],
          child: MaterialApp(
              theme: AppStyle.theme, home: const Scaffold(body: Player()))));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      CustomPainter armPainter() => tester
          .widget<CustomPaint>(find.descendant(
              of: find.byKey(const ValueKey('tonearm')),
              matching: find.byType(CustomPaint)))
          .painter!;
      final rect = tester.getRect(find.byKey(const ValueKey('vinyl-record')));
      final radius = rect.width * .43;
      final gesture =
          await tester.startGesture(rect.center + Offset(0, -radius));
      for (var i = 1; i <= 12; i++) {
        final angle = -math.pi / 2 + math.pi / 2 * i / 12;
        await gesture.moveTo(
            rect.center + Offset(math.cos(angle), math.sin(angle)) * radius);
        await tester.pump(const Duration(milliseconds: 16));
      }
      final preview = armPainter();
      await gesture.up();
      await tester.pump();
      expect(playback.target!.inMilliseconds, closeTo(60000, 1500));
      expect(tester.widget<VinylDeck>(find.byType(VinylDeck)).busy, isTrue);
      expect(tester.widget<VinylDeck>(find.byType(VinylDeck)).playing,
          playbackState == ap.PlayerState.playing);
      expect(armPainter().shouldRepaint(preview), isFalse,
          reason: 'Releasing a scrub must keep the needle at the preview');
      playback.updatePosition(const Duration(seconds: 46));
      await tester.pump(const Duration(milliseconds: 250));
      expect(armPainter().shouldRepaint(preview), isFalse,
          reason: 'Old position ticks must not move the needle during a seek');
      playback.pending.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.widget<VinylDeck>(find.byType(VinylDeck)).busy, isFalse);
      expect(armPainter().shouldRepaint(preview), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('record shelf scrolls through lazily loaded tracks',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tracks = List.generate(
        60, (index) => Track('record-$index', 'Record $index', 'Artist', ''));
    final playback = _Player();
    final queue = _ShelfQueue(tracks.map((track) => track.bvid).toList());
    await tester.pumpWidget(ProviderScope(overrides: [
      backgroundSettingsProvider.overrideWith(_BackgroundSettings.new),
      globalReadyProvider.overrideWith((ref) async {}),
      player.playerStateNotifierProvider.overrideWith(() => playback),
      currentPlaylistNotifierProvider.overrideWith(() => queue),
      playlistIdsNotifierProvider('favorite').overrideWith(_Ids.new),
      trackCoverProvider(tracks.first)
          .overrideWith((ref) async => throw StateError('no cover')),
      for (final track in tracks)
        trackProvider(track.bvid).overrideWith((ref) async => track),
    ], child: const ListenApp()));
    await tester.pumpAndSettle();
    playback.select(tracks.first);
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const ValueKey('vinyl-record')), const Offset(0, -100));
    await tester.pumpAndSettle();
    final shelf = find.byType(ListView);
    expect(find.descendant(of: shelf, matching: find.text('Record 0')),
        findsOneWidget);
    final scrollable =
        find.descendant(of: shelf, matching: find.byType(Scrollable));
    final position = tester.state<ScrollableState>(scrollable).position;
    await tester.drag(shelf, const Offset(0, -250),
        kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0),
        reason: 'Mouse dragging must scroll the record shelf on desktop');
    final mouseOffset = position.pixels;
    tester.binding.handlePointerEvent(PointerScrollEvent(
        position: tester.getCenter(shelf),
        scrollDelta: const Offset(0, 150),
        kind: PointerDeviceKind.mouse));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(mouseOffset));
    final wheelOffset = position.pixels;
    await tester.drag(shelf, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(wheelOffset));
    await tester.scrollUntilVisible(find.text('Record 59'), 300,
        scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(find.text('Record 59'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Record 59'));
    await tester.pumpAndSettle();
    expect(queue.playedId, tracks.last.bvid);
    expect(queue.state.playlist, tracks.map((track) => track.bvid).toList());
    expect(find.byType(ListView), findsNothing);
  });

  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(390, 844), 1.6),
  ]) {
    testWidgets('track titles keep layout and scroll stable at $size / $scale',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tracks = [
        Track('short', '晴天', '周杰伦', ''),
        Track('long', '这是一首很长很长的歌曲名称，包含翻唱版本与现场演出信息，超过两行也应保持布局稳定',
            'A very long artist name', ''),
        Track('mixed', 'Live 🎵\n特别现场版\nEncore', '', ''),
      ];
      final playback = _Player();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            backgroundSettingsProvider.overrideWith(_BackgroundSettings.new),
            player.playerStateNotifierProvider.overrideWith(() => playback),
            currentPlaylistNotifierProvider.overrideWith(() => _ShelfQueue([])),
            playlistIdsNotifierProvider('favorite').overrideWith(_Ids.new),
            for (final track in tracks)
              trackCoverProvider(track)
                  .overrideWith((ref) async => throw StateError('no cover')),
          ],
          child: MaterialApp(
              theme: AppStyle.theme,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: const Scaffold(body: Player()))));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      final offset = scroll.position.pixels;
      final extent = scroll.position.maxScrollExtent;
      final bounds = {
        for (final key in [
          'vinyl-record',
          'player-track-title',
          'player-track-singer'
        ])
          key: tester.getRect(find.byKey(ValueKey(key))),
      };

      for (final track in <Track?>[...tracks, null]) {
        playback.select(track);
        await tester.pumpAndSettle();
        for (final entry in bounds.entries) {
          expect(tester.getRect(find.byKey(ValueKey(entry.key))), entry.value,
              reason:
                  'Switching to ${track?.title} must not move ${entry.key}');
        }
        expect(scroll.position.pixels, offset);
        expect(scroll.position.maxScrollExtent, extent);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('playlist plus validates inputs and retries failed imports',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sources = _ImportSources();
    await tester.pumpWidget(ProviderScope(overrides: [
      backgroundSettingsProvider.overrideWith(_BackgroundSettings.new),
      globalReadyProvider.overrideWith((ref) async {}),
      bilibiliPlaylistsProvider.overrideWith(() => sources),
      player.playerStateNotifierProvider.overrideWith(_Player.new),
      playlistNamesProvider.overrideWith(_Names.new),
      playlistIdsNotifierProvider('favorite').overrideWith(_Ids.new),
      playlistIdsNotifierProvider('一个很长很长的歌单名称，用来验证小屏幕布局')
          .overrideWith(_Ids.new),
      playlistIdsNotifierProvider('收藏音乐').overrideWith(_Ids.new),
      playlistIdsNotifierProvider('空白歌单').overrideWith(_Ids.new),
    ], child: const ListenApp()));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('vinyl-record')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加歌单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建本地歌单'));
    await tester.pumpAndSettle();
    expect(find.text('请输入有效的收藏夹 ID'), findsNothing);
    expect(find.text('请输入歌单名称'), findsOneWidget);
    expect(sources.attempts, isEmpty);

    await tester.tap(find.text('平台导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入收藏夹'));
    await tester.pumpAndSettle();
    expect(find.text('请输入收藏夹链接或 ID'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '12345');
    await tester.enterText(find.byType(TextFormField).at(1), '收藏音乐');
    sources.pending = Completer<void>();
    await tester.tap(find.text('导入收藏夹'));
    await tester.pump();
    expect(sources.attempts, [
      ['收藏音乐', '12345']
    ]);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
            .onPressed,
        isNull);
    sources.pending!.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('导入失败，请检查收藏夹链接、访问权限或网络后重试'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        '12345');

    sources.pending = null;
    await tester.tap(find.text('导入收藏夹'));
    await tester.pumpAndSettle();
    expect(find.text('收藏音乐'), findsOneWidget);
    expect(find.text('歌单还是空的'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byTooltip('添加歌单'), findsOneWidget);
    await tester.tap(find.byTooltip('添加歌单'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '空白歌单');
    await tester.tap(find.text('创建本地歌单'));
    await tester.pumpAndSettle();
    expect(sources.attempts.last, ['空白歌单', '']);
    expect(find.text('空白歌单'), findsOneWidget);
    expect(find.text('歌单还是空的'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search playback replaces queue with all results in order',
      (tester) async {
    final tracks = [
      Track('first', 'First result', 'Artist', ''),
      Track('second', 'Second result', 'Artist', ''),
      Track('third', 'Third result', 'Artist', ''),
    ];
    final queue = _SearchQueue();
    final container = ProviderContainer(overrides: [
      backgroundSettingsProvider.overrideWith(_BackgroundSettings.new),
      searchResultProvider.overrideWith(() => _SearchResults(tracks)),
      currentPlaylistNotifierProvider.overrideWith(() => queue),
      playlistIdsNotifierProvider('favorite').overrideWith(_Ids.new),
      for (final track in tracks)
        trackCoverProvider(track)
            .overrideWith((ref) async => throw StateError('no cover')),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppStyle.theme, home: const Scaffold(body: Search()))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Second result'));
    await tester.pumpAndSettle();
    final state = container.read(currentPlaylistNotifierProvider);
    expect(queue.playedId, 'second');
    expect(state.playlist, ['first', 'second', 'third']);
    expect(state.index, 1);
    expect(state.hasNext, isTrue);
    expect(container.read(playlistIdsNotifierProvider('favorite')), isEmpty);

    await tester.tap(find.text('Third result'));
    await tester.pumpAndSettle();
    expect(queue.playedId, 'third');
    expect(container.read(currentPlaylistNotifierProvider).index, 2);
    expect(container.read(currentPlaylistNotifierProvider).playlist,
        ['first', 'second', 'third']);
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      backgroundSettingsProvider.overrideWith(_BackgroundSettings.new),
      playlistNamesProvider.overrideWith(_Names.new),
      bilibiliPlaylistsProvider.overrideWith(_Sources.new),
      playlistIdsNotifierProvider('favorite').overrideWith(_Ids.new),
      playlistIdsNotifierProvider('一个很长很长的歌单名称，用来验证小屏幕布局')
          .overrideWith(_Ids.new),
      player.playerStateNotifierProvider.overrideWith(_Player.new),
    ], child: MaterialApp(theme: AppStyle.theme, home: Scaffold(body: page))));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'physical shelf opens the queue and playlist picker without a gesture',
      (tester) async {
    await pumpPage(tester, const Player());
    final shelf = find.byKey(const ValueKey('record-shelf-open'));
    await tester.ensureVisible(shelf);
    await tester.tap(shelf);
    await tester.pumpAndSettle();
    expect(find.text('从歌单选择音乐，唱片会按顺序放入这里'), findsOneWidget);
    final choose = find.descendant(
        of: find.byType(BottomSheet), matching: find.text('选歌单'));
    await tester.tap(choose);
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistPicker), findsOneWidget);
    expect(find.text('我喜欢的'), findsOneWidget);
    Navigator.of(tester.element(find.byType(PlaylistPicker))).pop();
    await tester.pumpAndSettle();
    final playlists = find.byKey(const ValueKey('record-shelf-playlists'));
    await tester.ensureVisible(playlists);
    await tester.tap(playlists);
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistPicker), findsOneWidget);
    expect(find.text('我喜欢的'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('player previews the actual neighboring tracks from its queue',
      (tester) async {
    final tracks = [
      Track('previous', '真正的上一张', '', ''),
      _singleTrack,
      Track('next', '真正的下一张', '', ''),
    ];
    await tester.pumpWidget(ProviderScope(
        overrides: [
          backgroundSettingsProvider.overrideWith(_BackgroundSettings.new),
          player.playerStateNotifierProvider
              .overrideWith(_SingleTrackPlayer.new),
          currentPlaylistNotifierProvider.overrideWith(
              () => _ShelfQueue(tracks.map((track) => track.bvid).toList())),
          for (final track in tracks) ...[
            trackProvider(track.bvid).overrideWith((ref) async => track),
            trackCoverProvider(track)
                .overrideWith((ref) async => throw StateError('no cover')),
          ],
        ],
        child: MaterialApp(
            theme: AppStyle.theme, home: const Scaffold(body: Player()))));
    await tester.pumpAndSettle();
    final record = find.byKey(const ValueKey('vinyl-record'));
    for (final direction in [-1, 1]) {
      final drag = await tester.startGesture(tester.getCenter(record));
      await drag.moveBy(Offset(direction * 70.0, 0));
      await tester.pump();
      expect(find.text(direction < 0 ? '真正的下一张' : '真正的上一张'), findsOneWidget);
      await drag.cancel();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('app starts at turntable and center long press opens playlists',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      backgroundSettingsProvider.overrideWith(_BackgroundSettings.new),
      autoplayOnStartupProvider.overrideWith(_PlaybackSettings.new),
      globalReadyProvider.overrideWith((ref) async {}),
      bilibiliPlaylistsProvider.overrideWith(_Sources.new),
      player.playerStateNotifierProvider.overrideWith(_Player.new),
      playlistNamesProvider.overrideWith(_Names.new),
      playlistIdsNotifierProvider('favorite').overrideWith(_Ids.new),
      playlistIdsNotifierProvider('一个很长很长的歌单名称，用来验证小屏幕布局')
          .overrideWith(_Ids.new),
    ], child: const ListenApp()));
    await tester.pumpAndSettle();
    expect(find.byType(Player), findsOneWidget);
    expect(find.byTooltip('设置'), findsNothing);
    expect(find.byTooltip('选唱片'), findsNothing);
    expect(find.byTooltip('唱片架'), findsNothing);
    expect(find.byTooltip('返回'), findsNothing);
    await tester.longPress(find.byKey(const ValueKey('vinyl-record')));
    await tester.pumpAndSettle();
    expect(find.text('我喜欢的'), findsOneWidget);
    expect(find.text('一个很长很长的歌单名称，用来验证小屏幕布局'), findsOneWidget);
    await tester.tap(find.text('我喜欢的'));
    await tester.pumpAndSettle();
    expect(find.text('歌单还是空的'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('设置'), findsNothing);
    final heading = find.text('LISTEN 2');
    await tester.drag(heading, const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(find.text('背景外观'), findsNothing);
    await tester.drag(heading, const Offset(-40, 0));
    await tester.pumpAndSettle();
    expect(find.text('背景外观'), findsNothing);
    expect(find.byType(Search), findsNothing);
    await tester.drag(
        find.byKey(const ValueKey('vinyl-record')), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.text('背景外观'), findsNothing);

    await tester.drag(
        find.byKey(const ValueKey('vinyl-record')), const Offset(0, -100));
    await tester.pumpAndSettle();
    final shelfHeading = find.descendant(
        of: find.byType(BottomSheet), matching: find.text('唱片架'));
    expect(shelfHeading, findsOneWidget);
    expect(find.text('从歌单选择音乐，唱片会按顺序放入这里'), findsOneWidget);
    Navigator.of(tester.element(shelfHeading)).pop();
    await tester.pumpAndSettle();

    await tester.drag(heading, const Offset(120, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(find.byType(PageSurface)).left, lessThan(0),
        reason: 'Settings must enter from the left');
    await tester.pumpAndSettle();
    expect(find.text('背景外观'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(Player), findsOneWidget);

    await tester.drag(heading, const Offset(-120, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(find.byType(Search)).left, greaterThan(0),
        reason: 'Search must enter from the right');
    await tester.pumpAndSettle();
    expect(find.text('发现音乐'), findsOneWidget);
    expect(find.text('背景外观'), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(Player), findsOneWidget);
    await tester.ensureVisible(find.text('让音乐，慢慢转起来'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('让音乐，慢慢转起来'), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(find.text('背景外观'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(Player), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home opens search and returns on a narrow screen',
      (tester) async {
    await pumpPage(tester, const Home());
    expect(find.text('我喜欢的音乐'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('搜索歌曲、歌手或视频'));
    await tester.pumpAndSettle();
    expect(find.text('发现音乐'), findsOneWidget);
    expect(find.text('下一首心动，从这里开始'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('我的唱片'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty playlist keeps its back navigation available',
      (tester) async {
    await pumpPage(tester, const PlaylistPage(playlistName: 'favorite'));
    expect(find.text('歌单还是空的'), findsOneWidget);
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('player fits narrow screens with unknown duration',
      (tester) async {
    await pumpPage(tester, const Player());
    expect(find.text('0:00'), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.byKey(const ValueKey('tonearm')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('turntable instructions fit narrow screens', (tester) async {
    await pumpPage(tester, const Player());
    await tester.tap(find.byTooltip('操作说明'));
    await tester.pumpAndSettle();
    expect(find.text('像使用唱机一样聆听'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('instructions launch and replay tutorial without changing music',
      (tester) async {
    await pumpPage(tester, const Player(isHome: true));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(Player)));
    final playback = container.read(player.playerStateNotifierProvider);
    final favorites =
        List.of(container.read(playlistIdsNotifierProvider('favorite')));
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.byTooltip('操作说明'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始引导教程'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerTutorial), findsOneWidget);
      expect(find.text('第 1 / 7 步'), findsOneWidget);
      expect(find.text('像使用唱机一样聆听'), findsNothing);
      await tester.tap(find.byTooltip('退出教程'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerTutorial), findsNothing);
      expect(
          container.read(player.playerStateNotifierProvider), same(playback));
      expect(
          container.read(playlistIdsNotifierProvider('favorite')), favorites);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('queue boundaries show feedback on the matching record side',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          backgroundSettingsProvider.overrideWith(_BackgroundSettings.new),
          player.playerStateNotifierProvider
              .overrideWith(_SingleTrackPlayer.new),
          currentPlaylistNotifierProvider.overrideWith(_SingleTrackQueue.new),
          playlistIdsNotifierProvider('favorite').overrideWith(_Ids.new),
          trackCoverProvider(_singleTrack)
              .overrideWith((ref) async => throw StateError('no cover')),
        ],
        child: MaterialApp(
            theme: AppStyle.theme, home: const Scaffold(body: Player()))));
    await tester.pumpAndSettle();
    final record = find.byKey(const ValueKey('vinyl-record'));
    final rect = tester.getRect(record);
    await tester.drag(record, const Offset(90, 0));
    await tester.pump(const Duration(milliseconds: 300));
    final previous = find.byKey(const ValueKey('no-previous-track'));
    expect(previous, findsOneWidget);
    expect(find.text('没有上一曲'), findsNothing);
    expect(tester.getCenter(previous).dx, lessThan(rect.center.dx));
    await tester.drag(record, const Offset(-90, 0));
    await tester.pump(const Duration(milliseconds: 300));
    final next = find.byKey(const ValueKey('no-next-track'));
    expect(find.text('没有下一曲'), findsNothing);
    expect(tester.getCenter(next).dx, greaterThan(rect.center.dx));
    expect(previous, findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(next, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seek bar clamps invalid progress and supports tapping',
      (tester) async {
    double? sought;
    await pumpPage(
        tester,
        Center(
            child: ProgressBar(
                now: double.nan, onSeek: (value) async => sought = value)));
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    await tester.tapAt(tester.getCenter(find.byType(Slider)));
    await tester.pumpAndSettle();
    expect(sought, closeTo(0.5, 0.05));
    expect(tester.takeException(), isNull);
  });
}
