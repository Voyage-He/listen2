import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:listen2/src/provider/global/storage.dart';
import 'package:listen2/src/provider/repo/bilibili.dart';
import 'package:listen2/src/provider/repo/playlist_names.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/provider/repo/track.dart';

final bilibiliPlaylistsProvider =
    NotifierProvider<BilibiliPlaylists, Map<String, String>>(
        BilibiliPlaylists.new);

class BilibiliPlaylists extends Notifier<Map<String, String>> {
  static const _key = 'bilibiliPlaylistSources';

  @override
  Map<String, String> build() {
    final box = ref.watch(hiveStorageProvider).requireValue.value;
    final subscription = box.watch(key: _key).listen((_) {
      state = Map<String, String>.from(box.get(_key, defaultValue: {}));
    });
    ref.onDispose(subscription.cancel);
    return Map<String, String>.from(box.get(_key, defaultValue: {}));
  }

  Future<void> add(String name, String mediaId) async {
    name = name.trim();
    mediaId = mediaId.trim();
    if (name.isEmpty) throw const FormatException('请输入歌单名称');
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(mediaId)) {
      throw const FormatException('请输入有效的收藏夹数字 ID');
    }
    final names = await ref.read(playlistNamesProvider.future);
    if (names.contains(name) || name == 'favorite' || name == '我喜欢的') {
      throw const FormatException('歌单名称已存在，请使用其他名称');
    }
    final tracks = await fetchBilibiliPlaylist(ref, mediaId);
    if ((await ref.read(playlistNamesProvider.future)).contains(name)) {
      throw const FormatException('歌单名称已存在，请使用其他名称');
    }
    await ref
        .read(playlistIdsNotifierProvider(name).notifier)
        .set(tracks.map((track) => track.bvid).toList());
    final next = {...state, name: mediaId};
    await ref.read(hiveStorageProvider).requireValue.value.put(_key, next);
    state = next;
    await ref.read(playlistNamesProvider.notifier).add(name);
    await ref.read(playlistNamesProvider.notifier).load();
  }

  Future<void> remove(String name) async {
    if (!state.containsKey(name)) return;
    final next = {...state}..remove(name);
    await ref.read(hiveStorageProvider).requireValue.value.put(_key, next);
    state = next;
  }
}

Future<List<Track>> fetchBilibiliPlaylist(Ref ref, String mediaId) async {
  final client = await ref.read(bilibiliClientNotifierProvider.future);
  final videos = await client.getFavoriteList(mediaId);
  final tracks = videos
      .map((video) => Track(video.bvid, video.title, video.author,
          video.pic.startsWith('//') ? 'https:${video.pic}' : video.pic))
      .toList();
  final box = await Hive.openBox<Track>('tracks');
  await box.putAll({for (final track in tracks) track.bvid: track});
  return tracks;
}
