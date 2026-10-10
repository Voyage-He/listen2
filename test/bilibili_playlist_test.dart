import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:listen2/src/provider/global/storage.dart';
import 'package:listen2/src/provider/repo/bilibili.dart';
import 'package:listen2/src/provider/repo/bilibili_playlists.dart';
import 'package:listen2/src/provider/repo/playlist_names.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:listen2/src/view/page/playlist/playlist.dart';
import 'package:music_api/music_api.dart';

BilibiliVideoModel _video(String id) => BilibiliVideoModel.fromFavorite({
      'bvid': 'BV$id',
      'title': 'Song $id',
      'cover': '//example.com/cover.jpg',
      'upper': {'name': 'Artist'},
    });

class _Client extends BilibiliClient {
  _Client(super.box);
  List<BilibiliVideoModel> videos = [_video('first'), _video('second')];
  Object? error;
  int requests = 0;
  String? requestedId;
  @override
  Future<List<BilibiliVideoModel>> getFavoriteList(String mediaId) async {
    requests++;
    requestedId = mediaId;
    if (error != null) throw error!;
    return videos;
  }
}

class _ClientNotifier extends BilibiliClientNotifier {
  _ClientNotifier(this.client);
  final _Client client;
  @override
  Future<BilibiliClient> build() async => client;
}

void main() {
  late Directory directory;
  late Storage storage;
  late _Client client;
  late ProviderContainer container;
  ProviderContainer createContainer() => ProviderContainer(overrides: [
        hiveStorageProvider.overrideWith((ref) async => storage),
        bilibiliClientNotifierProvider
            .overrideWith(() => _ClientNotifier(client)),
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
    container = createContainer();
    await container.read(hiveStorageProvider.future);
  });

  tearDown(() async {
    container.dispose();
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

  test('opening remote playlist refreshes collection and playback IDs',
      () async {
    await container.read(bilibiliPlaylistsProvider.notifier).add('常听', '12345');
    client.videos = [_video('second'), _video('third')];
    final subscription =
        container.listen(playlistTracksProvider('常听'), (_, __) {});
    final tracks = await container.read(playlistTracksProvider('常听').future);
    expect(tracks.map((track) => track.bvid), ['second', 'third']);
    expect(
        container.read(playlistIdsNotifierProvider('常听')), ['second', 'third']);
    expect(client.requests, 2);
    subscription.close();
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
