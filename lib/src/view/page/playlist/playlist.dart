import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:listen2/src/provider/global/storage.dart';
import 'package:listen2/src/widget/app_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/current_playlist.dart';
import 'package:listen2/src/provider/repo/playlist_names.dart';
import 'package:listen2/src/provider/repo/bilibili_playlists.dart';
import 'package:listen2/src/widget/add_bilibili_playlist.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:listen2/src/widget/button/button.dart';
import 'package:listen2/src/widget/input/input.dart';
import 'package:listen2/src/widget/popup.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'playlist.g.dart';

@riverpod
Future<List<Track>> playlistTracks(
    PlaylistTracksRef ref, String playlistName) async {
  final mediaId = ref.watch(bilibiliPlaylistsProvider)[playlistName];
  if (mediaId != null) {
    final ids = ref.watch(playlistIdsNotifierProvider(playlistName));
    final box = await Hive.openBox<Track>('tracks');
    final storage = ref.read(hiveStorageProvider).requireValue;
    if (!storage.value.containsKey('${playlistName}playlistTracksId') ||
        ids.any((id) => !box.containsKey(id))) {
      await ref.read(bilibiliPlaylistsProvider.notifier).refresh(playlistName);
    }
  }
  List<String> ids = ref.watch(playlistIdsNotifierProvider(playlistName));

  List<Future<Track>> futures = [];

  for (final id in ids) {
    futures.add(ref.watch(trackProvider(id).future));
  }

  return await Future.wait(futures);
}

final popupTrackProvider = StateProvider<Track?>((ref) {
  return null;
});

final reverseProvider = StateProvider<bool>((ref) {
  return false;
});

@riverpod
Future<List<Track>> sortedList(SortedListRef ref, String playlistName) async {
  final tracks = await ref.watch(playlistTracksProvider(playlistName).future);
  final reverse = ref.watch(reverseProvider);
  if (reverse) {
    return tracks.reversed.toList();
  }
  return tracks;
}

@Riverpod(keepAlive: true)
class AddPlaylistNameNotifier extends _$AddPlaylistNameNotifier {
  @override
  String build() {
    return '';
  }

  update(String value) {
    state = value;
  }
}

class PlaylistPage extends ConsumerStatefulWidget {
  const PlaylistPage(
      {super.key,
      required this.playlistName,
      this.returnToPlayerOnPlay = false});
  final bool returnToPlayerOnPlay;
  final String playlistName;

  @override
  ConsumerState<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends ConsumerState<PlaylistPage> {
  final _actionPopupKey = GlobalKey<PopupState>();
  final _playlistSettingPopupKey = GlobalKey<PopupState>();
  final _addPlaylistPopupKey = GlobalKey<PopupState>();
  final _searchController = TextEditingController();
  String _query = '';
  String get playlistName => widget.playlistName;
  bool get returnToPlayerOnPlay => widget.returnToPlayerOnPlay;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlaylistPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlistName != playlistName) {
      _searchController.clear();
      _query = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTracks = ref.watch(sortedListProvider(playlistName));
    final query = _query.trim().toLowerCase();
    final tracks = allTracks.whenData((value) => query.isEmpty
        ? value
        : value
            .where((track) =>
                track.title.toLowerCase().contains(query) ||
                track.singer.toLowerCase().contains(query))
            .toList());
    final reverse = ref.watch(reverseProvider);
    final isRemote =
        ref.watch(bilibiliPlaylistsProvider).containsKey(playlistName);

    Future<void> refresh() async {
      try {
        await ref
            .read(bilibiliPlaylistsProvider.notifier)
            .refresh(playlistName);
        ref.invalidate(playlistTracksProvider(playlistName));
        await ref.read(playlistTracksProvider(playlistName).future);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('刷新失败，已保留本地歌单，请稍后重试')));
        }
      }
    }

    Widget refreshable(Widget child) =>
        isRemote ? RefreshIndicator(onRefresh: refresh, child: child) : child;

    Widget scrollableState(Widget child) => refreshable(
          LayoutBuilder(
              builder: (context, constraints) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: constraints.maxHeight, child: child)
                    ],
                  )),
        );

    final main = Column(children: [
      PageHeading(playlistName == 'favorite' ? '我喜欢的音乐' : playlistName,
          action: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                tooltip: reverse ? '恢复顺序' : '倒序排列',
                color: reverse ? AppStyle.accent : AppStyle.muted,
                onPressed: () =>
                    ref.read(reverseProvider.notifier).state = !reverse,
                icon: const Icon(Icons.swap_vert_rounded)),
            IconButton(
                tooltip: '添加歌单',
                icon: const Icon(Icons.add_rounded),
                onPressed: () async {
                  final name = await showAddBilibiliPlaylist(context);
                  if (name != null && context.mounted) {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (_) => PlaylistPage(
                            playlistName: name,
                            returnToPlayerOnPlay: returnToPlayerOnPlay)));
                  }
                }),
          ])),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(children: [
            const Icon(Icons.library_music_rounded,
                color: AppStyle.accent, size: 18),
            const SizedBox(width: 8),
            Text(
                query.isEmpty
                    ? '${ref.watch(playlistIdsNotifierProvider(playlistName)).length} 首歌曲'
                    : '${tracks.valueOrNull?.length ?? 0} / ${ref.watch(playlistIdsNotifierProvider(playlistName)).length} 首歌曲',
                style: Theme.of(context).textTheme.bodyMedium),
          ])),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: '搜索歌单内的歌曲或歌手',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空搜索',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      _searchController.clear();
                      _query = '';
                    }),
                  ),
          ),
        ),
      ),
      Expanded(
          child: tracks.when(
        data: (value) => value.isEmpty
            ? scrollableState(query.isNotEmpty
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: '没有找到匹配的歌曲',
                    message: '试试其他关键词，或清空搜索')
                : const EmptyState(
                    icon: Icons.queue_music_rounded,
                    title: '歌单还是空的',
                    message: '搜索喜欢的音乐，将它们收藏到这里'))
            : refreshable(ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: value.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) =>
                    _trackItem(index, value[index], context, ref))),
        error: (_, __) => scrollableState(EmptyState(
            icon: Icons.wifi_off_rounded,
            title: '歌曲加载失败',
            message: '请检查网络后重试',
            action: TextButton(
                onPressed: () =>
                    ref.invalidate(playlistTracksProvider(playlistName)),
                child: const Text('重试')))),
        loading: () => const Center(child: CircularProgressIndicator()),
      )),
    ]);

    final track = ref.watch(popupTrackProvider);
    return PageSurface(
        child: Stack(children: [
      main,
      Popup(
        track == null
            ? Container()
            : Center(
                child: Column(
                  children: [
                    if (!ref
                        .watch(bilibiliPlaylistsProvider)
                        .containsKey(playlistName))
                      Button(
                        onTap: () {
                          ref
                              .read(playlistIdsNotifierProvider(playlistName)
                                  .notifier)
                              .toggle(track.bvid);
                          _actionPopupKey.currentState!.toggle();
                        },
                        child:
                            Text(playlistName == 'favorite' ? '取消收藏' : '移出歌单'),
                      ),
                    Button(
                      onTap: () {
                        _actionPopupKey.currentState!.toggle();
                        _playlistSettingPopupKey.currentState!.toggle();
                      },
                      child: const Text('加入歌单'),
                    ),
                  ],
                ),
              ),
        key: _actionPopupKey,
      ),
      _playlistSettingPopup(ref, track),
      _addPlaylistPopup(ref, track),
    ]));
  }

  Widget _trackItem(
          int index, Track track, BuildContext context, WidgetRef ref) =>
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            try {
              await ref.read(currentPlaylistNotifierProvider.notifier).play(
                  track.bvid,
                  ref.read(playlistIdsNotifierProvider(playlistName)));
              if (returnToPlayerOnPlay && context.mounted) {
                Navigator.of(context).pop();
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('暂时无法播放，请稍后重试')));
              }
            }
          },
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(children: [
                SizedBox(
                    width: 32,
                    child: Text('${index + 1}'.padLeft(2, '0'),
                        style: const TextStyle(
                            color: AppStyle.muted, fontSize: 13))),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15,
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
                    tooltip: '歌曲操作',
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: AppStyle.muted),
                    onPressed: () {
                      ref.read(popupTrackProvider.notifier).state = track;
                      _actionPopupKey.currentState!.toggle();
                    }),
              ])),
        ),
      );

  Widget _playlistSettingPopup(WidgetRef ref, Track? track) {
    final playlistNames = ref.watch(playlistNamesProvider);
    final remoteNames = ref.watch(bilibiliPlaylistsProvider).keys;
    final localNames = playlistNames.valueOrNull
            ?.where((name) => !remoteNames.contains(name))
            .toList() ??
        <String>[];
    // final playlistIds = ref.watch(playlistIdsProvider[playlistNames.valueOrNull![0]]);
    return Popup(
      track == null
          ? Container()
          : Center(
              child: Column(
                children: [
                  Button(
                    onTap: () {
                      _playlistSettingPopupKey.currentState!.toggle();
                      ref
                          .read(addPlaylistNameNotifierProvider.notifier)
                          .update('');
                      _addPlaylistPopupKey.currentState!.toggle();
                    },
                    child: const Text('新建歌单'),
                  ),
                  if (localNames.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: localNames.length,
                        itemBuilder: (context, index) {
                          final name = localNames[index];
                          final isCollected = ref
                              .watch(playlistIdsNotifierProvider(name))
                              .contains(track.bvid);
                          return Button(
                            onTap: () {
                              ref
                                  .read(playlistIdsNotifierProvider(name)
                                      .notifier)
                                  .toggle(track.bvid);
                            },
                            color:
                                isCollected ? AppStyle.muted : AppStyle.accent,
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(
                                        name == 'favorite' ? '我喜欢的音乐' : name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)),
                                Icon(isCollected ? Icons.check : Icons.add),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
      key: _playlistSettingPopupKey,
    );
  }

  Widget _addPlaylistPopup(WidgetRef ref, Track? track) {
    return Popup(
      track == null
          ? Container()
          : Center(
              child: Column(
                children: [
                  Input(
                    onChange: (text) {
                      ref
                          .read(addPlaylistNameNotifierProvider.notifier)
                          .update(text);
                    },
                    onDone: () {
                      final name =
                          ref.read(addPlaylistNameNotifierProvider).trim();
                      if (name.isEmpty) return;
                      ref.read(playlistNamesProvider.notifier).add(name);
                      ref
                          .read(playlistIdsNotifierProvider(name).notifier)
                          .add(track.bvid);
                      ref
                          .read(addPlaylistNameNotifierProvider.notifier)
                          .update('');
                      _addPlaylistPopupKey.currentState!.toggle();
                    },
                  ),
                  Button(
                    onTap: () {
                      final name =
                          ref.read(addPlaylistNameNotifierProvider).trim();
                      if (name.isEmpty) return;
                      ref.read(playlistNamesProvider.notifier).add(name);
                      ref
                          .read(playlistIdsNotifierProvider(name).notifier)
                          .add(track.bvid);
                      ref
                          .read(addPlaylistNameNotifierProvider.notifier)
                          .update('');
                      _addPlaylistPopupKey.currentState!.toggle();
                    },
                    child: const Text('确认'),
                  ),
                ],
              ),
            ),
      key: _addPlaylistPopupKey,
    );
  }
}
