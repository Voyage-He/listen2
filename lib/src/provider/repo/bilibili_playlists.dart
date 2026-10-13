import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:listen2/src/provider/global/storage.dart';
import 'package:listen2/src/provider/repo/bilibili.dart';
import 'package:listen2/src/provider/repo/bilibili_account.dart';
import 'package:listen2/src/provider/repo/playlist_names.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:music_api/music_api.dart';

String parseBilibiliFavoriteId(String input) {
  input = input.trim();
  final validId = RegExp(r'^[1-9][0-9]*$');
  if (validId.hasMatch(input)) return input;
  final uri = Uri.tryParse(input);
  if (uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      (uri.host == 'bilibili.com' || uri.host.endsWith('.bilibili.com'))) {
    final id = uri.queryParameters['fid'] ??
        RegExp(r'(?:^|/)ml([1-9][0-9]*)(?:/|$)').firstMatch(uri.path)?.group(1);
    if (id != null && validId.hasMatch(id)) return id;
  }
  throw const FormatException('请输入有效的 Bilibili 收藏夹链接或数字 ID');
}

final bilibiliPlaylistsProvider =
    NotifierProvider<BilibiliPlaylists, Map<String, String>>(
        BilibiliPlaylists.new);

class BilibiliPlaylists extends Notifier<Map<String, String>> {
  static const _key = 'bilibiliPlaylistSources';
  final _refreshes = <String, Future<void>>{};
  final _writeVersions = <String, int>{};

  Future<void> setFavorite(String name, String trackId,
      {required bool saved}) async {
    final mediaId = state[name];
    if (mediaId == null) throw StateError('收藏夹来源已移除，请重新选择');
    final account = ref.read(bilibiliAccountClientProvider);
    final user = await account.getLoggedInUser();
    if (user == null) {
      throw const BilibiliApiException(-101, '请先登录 Bilibili，再操作这个收藏夹');
    }
    final avid = await account.getVideoAid(trackId);
    final folders = await account.getFavoriteFolders(avid: avid);
    final owned = folders.where((folder) => '${folder.id}' == mediaId).toList();
    if (owned.isEmpty) {
      throw const BilibiliApiException(-403, '这个收藏夹不属于当前登录账号，只能查看');
    }
    if (state[name] != mediaId) throw StateError('收藏夹来源已更改，请重新选择');
    if (owned.single.containsVideo != saved) {
      await account.setFavorite(avid, owned.single.id, saved: saved);
    }
    // Update membership only after the server accepts the operation. Also update
    // any other local playlists imported from the same folder.
    final aliases = state.entries
        .where((entry) => entry.value == mediaId)
        .map((entry) => entry.key)
        .toList();
    for (final alias in aliases) {
      if (state[alias] != mediaId) continue;
      _writeVersions[alias] = (_writeVersions[alias] ?? 0) + 1;
      final ids = ref.read(playlistIdsNotifierProvider(alias));
      final next = ids.where((id) => id != trackId).toList();
      if (saved) next.insert(0, trackId);
      await ref.read(playlistIdsNotifierProvider(alias).notifier).set(next);
    }
    for (final alias in aliases) {
      if (state[alias] != mediaId) continue;
      try {
        await _refreshes[alias];
        await refresh(alias);
      } catch (_) {
        // The remote write succeeded; keep its local membership if a later
        // refresh is offline. Pull-to-refresh can load the full contents later.
      }
    }
  }

  Future<void> refresh(String name) {
    return _refreshes.putIfAbsent(name, () async {
      try {
        final mediaId = state[name];
        if (mediaId == null) return;
        final version = _writeVersions[name];
        final tracks = await fetchBilibiliPlaylist(ref, mediaId);
        // A deleted or replaced source must not be restored by a late response.
        if (state[name] != mediaId || _writeVersions[name] != version) return;
        await ref
            .read(playlistIdsNotifierProvider(name).notifier)
            .set(tracks.map((track) => track.bvid).toList());
        for (final track in tracks) {
          ref.invalidate(trackProvider(track.bvid));
        }
      } finally {
        _refreshes.remove(name);
      }
    });
  }

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
    if (mediaId.isNotEmpty) mediaId = parseBilibiliFavoriteId(mediaId);
    final names = await ref.read(playlistNamesProvider.future);
    if (names.contains(name) || name == 'favorite' || name == '我喜欢的') {
      throw const FormatException('歌单名称已存在，请使用其他名称');
    }
    final tracks =
        mediaId.isEmpty ? <Track>[] : await fetchBilibiliPlaylist(ref, mediaId);
    if ((await ref.read(playlistNamesProvider.future)).contains(name)) {
      throw const FormatException('歌单名称已存在，请使用其他名称');
    }
    await ref
        .read(playlistIdsNotifierProvider(name).notifier)
        .set(tracks.map((track) => track.bvid).toList());
    if (mediaId.isNotEmpty) {
      final next = {...state, name: mediaId};
      await ref.read(hiveStorageProvider).requireValue.value.put(_key, next);
      state = next;
    }
    await ref.read(playlistNamesProvider.notifier).add(name);
    await ref.read(playlistNamesProvider.notifier).load();
  }

  Future<void> remove(String name) async {
    if (!state.containsKey(name)) return;
    final next = {...state}..remove(name);
    await ref.read(hiveStorageProvider).requireValue.value.put(_key, next);
    _writeVersions[name] = (_writeVersions[name] ?? 0) + 1;
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
  final changed = <String, Track>{};
  for (final track in tracks) {
    final cached = box.get(track.bvid);
    if (cached == null ||
        cached.title != track.title ||
        cached.singer != track.singer ||
        cached.pictureUrl != track.pictureUrl) {
      changed[track.bvid] = track;
    }
  }
  if (changed.isNotEmpty) await box.putAll(changed);
  return tracks;
}
