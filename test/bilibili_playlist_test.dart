import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:listen2/src/provider/global/storage.dart';
import 'package:listen2/src/provider/repo/bilibili.dart';
import 'package:listen2/src/provider/repo/bilibili_account.dart';
import 'package:listen2/src/provider/repo/bilibili_playlists.dart';
import 'package:listen2/src/provider/repo/playlist_names.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:listen2/src/view/page/playlist/playlist.dart';
import 'package:music_api/music_api.dart';

BilibiliVideoModel _video(String id, {String? title}) =>
    BilibiliVideoModel.fromFavorite({
      'bvid': 'BV$id',
      'title': title ?? 'Song $id',
      'cover': '//example.com/cover.jpg',
      'upper': {'name': 'Artist'},
    });

class _Client extends BilibiliClient {
  _Client(super.box);
  List<BilibiliVideoModel> videos = [_video('first'), _video('second')];
  Object? error;
  int requests = 0;
  String? requestedId;
  Completer<List<BilibiliVideoModel>>? pending;
  @override
  Future<List<BilibiliVideoModel>> getFavoriteList(String mediaId) async {
    requests++;
    requestedId = mediaId;
    if (error != null) throw error!;
    final paused = pending;
    pending = null;
    if (paused != null) return paused.future;
    return videos;
  }
}

class _ClientNotifier extends BilibiliClientNotifier {
  _ClientNotifier(this.client);
  final _Client client;
  @override
  Future<BilibiliClient> build() async => client;
}

class _SessionStore implements BilibiliSessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String _) async {}
  @override
  Future<void> delete() async {}
}

class _Account extends BilibiliAccountClient {
  _Account() : super(_SessionStore());
  bool owned = true;
  bool saved = false;
  Object? failure;
  final writes = <(int, int, bool)>[];
  void Function(bool)? onWrite;
  @override
  Future<BilibiliUser?> getLoggedInUser() async => user;
  @override
  Future<int> getVideoAid(String bvid) async => 456;
  @override
  Future<List<BilibiliFavoriteFolder>> getFavoriteFolders({int? avid}) async =>
      owned
          ? [
              BilibiliFavoriteFolder(
                  id: 12345,
                  title: '常听',
                  count: 2,
                  isPrivate: false,
                  containsVideo: saved)
            ]
          : [];
  @override
  Future<void> setFavorite(int avid, int folderId,
      {required bool saved}) async {
    if (failure != null) throw failure!;
    writes.add((avid, folderId, saved));
    this.saved = saved;
    onWrite?.call(saved);
  }
}

void main() {
  late Directory directory;
  late Storage storage;
  late _Client client;
  late _Account account;
  late ProviderContainer container;
  ProviderContainer createContainer() => ProviderContainer(overrides: [
        hiveStorageProvider.overrideWith((ref) async => storage),
        bilibiliClientNotifierProvider
            .overrideWith(() => _ClientNotifier(client)),
        bilibiliAccountClientProvider.overrideWithValue(account),
      ]);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('listen2-playlist-test-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TrackAdapter());
    final value = await Hive.openBox('value');
    storage =
        Storage(value, value, await Hive.openBox<Uint8List>('binary'), {});
    await value.put('favoriteplaylistTracksId', ['existing']);
    client = _Client(value);
    account = _Account();
    container = createContainer();
    await container.read(hiveStorageProvider.future);
  });

  tearDown(() async {
    container.dispose();
    account.close();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('import persists source, order and metadata without changing favorites',
      () async {
    await container
        .read(bilibiliPlaylistsProvider.notifier)
        .add(' 常听 ', ' 12345 ');
    expect(client.requestedId, '12345');
    expect(
        await container.read(playlistNamesProvider.future), ['favorite', '常听']);
    expect(
        container.read(playlistIdsNotifierProvider('常听')), ['first', 'second']);
    expect(
        container.read(playlistIdsNotifierProvider('favorite')), ['existing']);
    final cached = Hive.box<Track>('tracks').get('first')!;
    expect(cached.title, 'Song first');
    expect(cached.pictureUrl, 'https://example.com/cover.jpg');

    container.dispose();
    container = createContainer();
    await container.read(hiveStorageProvider.future);
    expect(container.read(bilibiliPlaylistsProvider), {'常听': '12345'});
    expect(
        await container.read(playlistNamesProvider.future), ['favorite', '常听']);
    expect(
        container.read(playlistIdsNotifierProvider('常听')), ['first', 'second']);
  });

  test('removing a song persists only in the selected local playlist',
      () async {
    await container
        .read(playlistIdsNotifierProvider('日常').notifier)
        .set(['existing', 'other']);
    await container
        .read(playlistIdsNotifierProvider('favorite').notifier)
        .delete('existing');
    expect(container.read(playlistIdsNotifierProvider('favorite')), isEmpty);
    expect(container.read(playlistIdsNotifierProvider('日常')),
        ['existing', 'other']);
    container.dispose();
    container = createContainer();
    await container.read(hiveStorageProvider.future);
    expect(container.read(playlistIdsNotifierProvider('favorite')), isEmpty);
    await container
        .read(playlistIdsNotifierProvider('日常').notifier)
        .delete('existing');
    container.dispose();
    container = createContainer();
    await container.read(hiveStorageProvider.future);
    expect(container.read(playlistIdsNotifierProvider('日常')), ['other']);
    expect(container.read(playlistIdsNotifierProvider('favorite')), isEmpty);
  });

  test('one song can be persisted in a new playlist and favorites', () async {
    await container.read(bilibiliPlaylistsProvider.notifier).add('新歌单', '');
    await container
        .read(playlistIdsNotifierProvider('新歌单').notifier)
        .add('new-track');
    await container
        .read(playlistIdsNotifierProvider('favorite').notifier)
        .add('new-track');
    container.dispose();
    container = createContainer();
    await container.read(hiveStorageProvider.future);
    expect(await container.read(playlistNamesProvider.future),
        ['favorite', '新歌单']);
    expect(container.read(playlistIdsNotifierProvider('新歌单')), ['new-track']);
    expect(container.read(playlistIdsNotifierProvider('favorite')),
        ['existing', 'new-track']);
  });

  test('opening remote playlist uses persisted content until explicit refresh',
      () async {
    await container.read(bilibiliPlaylistsProvider.notifier).add('常听', '12345');
    client.videos = [_video('second'), _video('third')];
    final subscription =
        container.listen(playlistTracksProvider('常听'), (_, __) {});
    final cached = await container.read(playlistTracksProvider('常听').future);
    expect(cached.map((track) => track.bvid), ['first', 'second']);
    expect(client.requests, 1);
    await container.read(bilibiliPlaylistsProvider.notifier).refresh('常听');
    final tracks = await container.read(playlistTracksProvider('常听').future);
    expect(tracks.map((track) => track.bvid), ['second', 'third']);
    expect(
        container.read(playlistIdsNotifierProvider('常听')), ['second', 'third']);
    expect(client.requests, 2);
    subscription.close();
  });

  test('cached content survives restart and remains available offline',
      () async {
    await container.read(bilibiliPlaylistsProvider.notifier).add('常听', '123');
    container.dispose();
    await Hive.close();
    final value = await Hive.openBox('value');
    storage =
        Storage(value, value, await Hive.openBox<Uint8List>('binary'), {});
    container = createContainer();
    await container.read(hiveStorageProvider.future);
    client.error = StateError('offline');
    final subscription =
        container.listen(playlistTracksProvider('常听'), (_, __) {});
    final tracks = await container.read(playlistTracksProvider('常听').future);
    expect(tracks.map((track) => track.bvid), ['first', 'second']);
    expect(client.requests, 1);
    await expectLater(
      container.read(bilibiliPlaylistsProvider.notifier).refresh('常听'),
      throwsStateError,
    );
    expect(
        container.read(playlistIdsNotifierProvider('常听')), ['first', 'second']);
    expect(
        (await container.read(playlistTracksProvider('常听').future)).first.title,
        'Song first');
    subscription.close();
  });

  test('empty imported playlist is cached without repeated requests', () async {
    client.videos = [];
    await container.read(bilibiliPlaylistsProvider.notifier).add('空歌单', '123');
    final subscription =
        container.listen(playlistTracksProvider('空歌单'), (_, __) {});
    expect(await container.read(playlistTracksProvider('空歌单').future), isEmpty);
    container.invalidate(playlistTracksProvider('空歌单'));
    expect(await container.read(playlistTracksProvider('空歌单').future), isEmpty);
    expect(client.requests, 1);
    subscription.close();
  });

  test('concurrent refreshes share a request and update cached metadata',
      () async {
    await container.read(bilibiliPlaylistsProvider.notifier).add('常听', '123');
    client.videos = [_video('first', title: 'Updated title')];
    final notifier = container.read(bilibiliPlaylistsProvider.notifier);
    await Future.wait([notifier.refresh('常听'), notifier.refresh('常听')]);
    expect(client.requests, 2);
    expect(Hive.box<Track>('tracks').get('first')!.title, 'Updated title');
    expect(container.read(playlistIdsNotifierProvider('常听')), ['first']);
  });

  test('blank ID creates an editable empty playlist without a network request',
      () async {
    await container.read(bilibiliPlaylistsProvider.notifier).add(' 日常 ', ' ');
    expect(client.requests, 0);
    expect(container.read(bilibiliPlaylistsProvider), isEmpty);
    expect(
        await container.read(playlistNamesProvider.future), ['favorite', '日常']);
    expect(container.read(playlistIdsNotifierProvider('日常')), isEmpty);
    await container
        .read(playlistIdsNotifierProvider('日常').notifier)
        .add('song');
    await container
        .read(playlistIdsNotifierProvider('日常').notifier)
        .add('song');
    expect(container.read(playlistIdsNotifierProvider('日常')), ['song']);
    container.dispose();
    container = createContainer();
    await container.read(hiveStorageProvider.future);
    expect(
        await container.read(playlistNamesProvider.future), ['favorite', '日常']);
    expect(container.read(playlistIdsNotifierProvider('日常')), ['song']);
    expect(container.read(bilibiliPlaylistsProvider), isEmpty);
  });

  test('imported playlists require login before changing platform favorites',
      () async {
    await container.read(bilibiliPlaylistsProvider.notifier).add('常听', '12345');
    await expectLater(
        container.read(playlistIdsNotifierProvider('常听').notifier).add('song'),
        throwsA(
            isA<BilibiliApiException>().having((e) => e.code, 'code', -101)));
    expect(
        container.read(playlistIdsNotifierProvider('常听')), ['first', 'second']);
    expect(storage.value.get('常听playlistTracksId'), ['first', 'second']);
  });

  test(
      'owned imported folders write to Bilibili and synchronize all local aliases',
      () async {
    account.user = const BilibiliUser(mid: 123, name: 'owner');
    await container.read(bilibiliPlaylistsProvider.notifier).add('常听', '12345');
    await container
        .read(bilibiliPlaylistsProvider.notifier)
        .add('同一个收藏夹', '12345');
    account.onWrite = (saved) {
      client.videos = [
        _video('first'),
        _video('second'),
        if (saved) _video('song')
      ];
    };
    await container
        .read(playlistIdsNotifierProvider('常听').notifier)
        .add('song');
    expect(account.writes, [(456, 12345, true)]);
    expect(container.read(playlistIdsNotifierProvider('常听')),
        ['first', 'second', 'song']);
    expect(container.read(playlistIdsNotifierProvider('同一个收藏夹')),
        ['first', 'second', 'song']);
    await container
        .read(playlistIdsNotifierProvider('常听').notifier)
        .delete('song');
    expect(account.writes.last, (456, 12345, false));
    expect(
        container.read(playlistIdsNotifierProvider('常听')), ['first', 'second']);
    expect(container.read(playlistIdsNotifierProvider('同一个收藏夹')),
        ['first', 'second']);
    expect(
        container.read(playlistIdsNotifierProvider('favorite')), ['existing']);
  });

  test(
      'foreign folders and failed platform writes do not alter the local snapshot',
      () async {
    account.user = const BilibiliUser(mid: 123, name: 'owner');
    await container.read(bilibiliPlaylistsProvider.notifier).add('常听', '12345');
    account.owned = false;
    await expectLater(
        container.read(playlistIdsNotifierProvider('常听').notifier).add('song'),
        throwsA(
            isA<BilibiliApiException>().having((e) => e.code, 'code', -403)));
    expect(account.writes, isEmpty);
    account.owned = true;
    account.failure = const BilibiliApiException(-403, 'failed');
    await expectLater(
        container.read(playlistIdsNotifierProvider('常听').notifier).add('song'),
        throwsA(isA<BilibiliApiException>()));
    expect(
        container.read(playlistIdsNotifierProvider('常听')), ['first', 'second']);
    expect(storage.value.get('常听playlistTracksId'), ['first', 'second']);
  });

  test(
      'successful server write survives a failed refresh and is not sent twice',
      () async {
    account.user = const BilibiliUser(mid: 123, name: 'owner');
    await container.read(bilibiliPlaylistsProvider.notifier).add('常听', '12345');
    client.error = StateError('offline after write');
    await container
        .read(playlistIdsNotifierProvider('常听').notifier)
        .add('song');
    expect(container.read(playlistIdsNotifierProvider('常听')),
        ['song', 'first', 'second']);
    await container
        .read(playlistIdsNotifierProvider('常听').notifier)
        .add('song');
    expect(account.writes, [(456, 12345, true)]);
    expect(
        storage.value.get('常听playlistTracksId'), ['song', 'first', 'second']);
  });

  test('invalid and duplicate names cannot overwrite existing playlists',
      () async {
    final sources = container.read(bilibiliPlaylistsProvider.notifier);
    await expectLater(sources.add('', '123'), throwsFormatException);
    await expectLater(sources.add('常听', 'BV123'), throwsFormatException);
    await expectLater(sources.add('favorite', '123'), throwsFormatException);
    await sources.add('常听', '123');
    await expectLater(sources.add('常听', '456'), throwsFormatException);
    expect(client.requests, 1);
    expect(container.read(bilibiliPlaylistsProvider), {'常听': '123'});
  });

  test(
      'a refresh started before a platform write cannot restore stale membership',
      () async {
    account.user = const BilibiliUser(mid: 123, name: 'owner');
    await container.read(bilibiliPlaylistsProvider.notifier).add('常听', '12345');
    final oldResponse = Completer<List<BilibiliVideoModel>>();
    client.pending = oldResponse;
    final oldRefresh =
        container.read(bilibiliPlaylistsProvider.notifier).refresh('常听');
    await Future<void>.delayed(Duration.zero);
    account.onWrite = (_) => client.videos = [_video('song'), _video('first')];
    final write =
        container.read(playlistIdsNotifierProvider('常听').notifier).add('song');
    await Future<void>.delayed(Duration.zero);
    oldResponse.complete([_video('first'), _video('second')]);
    await oldRefresh;
    await write;
    expect(
        container.read(playlistIdsNotifierProvider('常听')), ['song', 'first']);
  });

  test('network failure does not create a partial playlist', () async {
    client.error = StateError('offline');
    await expectLater(
        container.read(bilibiliPlaylistsProvider.notifier).add('常听', '123'),
        throwsStateError);
    expect(container.read(bilibiliPlaylistsProvider), isEmpty);
    expect(await container.read(playlistNamesProvider.future), ['favorite']);
    expect(storage.value.get('常听playlistTracksId'), isNull);
  });

  test('deleting imported playlist clears its source before name reuse',
      () async {
    await container.read(bilibiliPlaylistsProvider.notifier).add('常听', '123');
    await container.read(playlistNamesProvider.notifier).delete('常听');
    expect(container.read(bilibiliPlaylistsProvider), isEmpty);
    await container.read(playlistNamesProvider.notifier).add('常听');
    expect(container.read(bilibiliPlaylistsProvider), isEmpty);
  });
}
