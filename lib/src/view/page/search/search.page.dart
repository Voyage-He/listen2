import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/current_playlist.dart';
import 'package:listen2/src/provider/repo/bilibili.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/provider/repo/track.dart';

import 'package:listen2/src/widget/input/input.dart';
import 'package:listen2/src/widget/app_style.dart';
import 'package:listen2/src/widget/track_cover.widget.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search.page.g.dart';

@Riverpod(keepAlive: true)
class KeywordNotifier extends _$KeywordNotifier {
  @override
  String build() {
    return '';
  }

  update(String value) {
    state = value;
  }
}

@Riverpod(keepAlive: true)
class SearchResult extends _$SearchResult {
  int _request = 0;

  @override
  Future<List<Track>> build() async {
    ref.onDispose(() => _request++);
    return [];
  }

  Future<void> search() async {
    final request = ++_request;
    final keyword = ref.read(keywordNotifierProvider).trim();
    if (keyword.isEmpty) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final client = await ref.read(bilibiliClientNotifierProvider.future);
      if (!client.hasCookie) throw StateError('搜索服务尚未初始化');
      final videos = await client.search(keyword);
      return videos.map((video) {
        final pictureUrl =
            video.pic.startsWith('//') ? 'https:${video.pic}' : video.pic;
        return Track(video.bvid, video.title, video.author, pictureUrl);
      }).toList();
    });
    if (request == _request) state = result;
  }
}

@riverpod
Future<Map<String, dynamic>> tracksAndIsFavirite(
    TracksAndIsFaviriteRef ref) async {
  var tracks = await ref.watch(searchResultProvider.future);
  var favo = ref.watch(playlistIdsNotifierProvider('favorite'));
  var isFavorite =
      List.generate(tracks.length, (i) => favo.contains(tracks[i].bvid));
  return {'tracks': tracks, 'isFavorite': isFavorite};
}

class Search extends ConsumerWidget {
  const Search({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyword = ref.watch(keywordNotifierProvider);
    final results = ref.watch(searchResultProvider);
    return Material(
        color: AppStyle.background,
        child: Column(children: [
          const PageHeading('发现音乐'),
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(children: [
                Expanded(
                    child: Input(
                        hintText: '搜索歌曲、歌手或视频',
                        initialValue: keyword,
                        textInputAction: TextInputAction.search,
                        onChange: (text) => ref
                            .read(keywordNotifierProvider.notifier)
                            .update(text),
                        onDone: () =>
                            ref.read(searchResultProvider.notifier).search())),
                const SizedBox(width: 8),
                IconButton.filled(
                    tooltip: '搜索',
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      ref.read(searchResultProvider.notifier).search();
                    },
                    icon: const Icon(Icons.search_rounded)),
              ])),
          Expanded(
              child: results.when(
            skipLoadingOnRefresh: false,
            data: (tracks) => tracks.isEmpty
                ? EmptyState(
                    icon: Icons.headphones_rounded,
                    title: keyword.trim().isEmpty ? '下一首心动，从这里开始' : '暂时没有搜索结果',
                    message: keyword.trim().isEmpty
                        ? '搜索喜欢的歌曲或歌手，发现更多好音乐'
                        : '试试其他歌曲名称或关键词')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: tracks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _searchItem(context, ref, tracks[index], tracks)),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => EmptyState(
                icon: Icons.wifi_off_rounded,
                title: '搜索失败',
                message: '请检查网络连接后重试',
                action: FilledButton.tonal(
                    onPressed: () =>
                        ref.read(searchResultProvider.notifier).search(),
                    child: const Text('重新搜索'))),
          )),
        ]));
  }

  Widget _searchItem(
      BuildContext context, WidgetRef ref, Track track, List<Track> results) {
    final isFavorite =
        ref.watch(playlistIdsNotifierProvider('favorite')).contains(track.bvid);
    return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            try {
              await ref.read(currentPlaylistNotifierProvider.notifier).play(
                  track.bvid, results.map((result) => result.bvid).toList());
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('暂时无法播放，请稍后重试')));
              }
            }
          },
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: TrackCover(track,
                        width: 56, height: 56, fit: BoxFit.cover)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppStyle.ink)),
                      const SizedBox(height: 6),
                      Text(track.singer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppStyle.muted)),
                    ])),
                IconButton(
                    tooltip: isFavorite ? '取消收藏' : '收藏',
                    onPressed: () => ref
                        .read(playlistIdsNotifierProvider('favorite').notifier)
                        .toggle(track.bvid),
                    icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite ? AppStyle.accent : AppStyle.muted,
                        size: 22)),
              ])),
        ));
  }
}
