import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/repo/bilibili_playlists.dart';
import 'package:listen2/src/provider/repo/playlist_names.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';
import 'package:listen2/src/widget/add_bilibili_playlist.dart';

class PlaylistPicker extends ConsumerWidget {
  const PlaylistPicker({super.key, this.trackId});
  final String? trackId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importedNames = trackId == null
        ? <String>{}
        : ref.watch(bilibiliPlaylistsProvider).keys.toSet();
    return SafeArea(
      top: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 16, 18),
            child: Row(children: [
              Expanded(
                  child: Text(trackId == null ? '歌单' : '收藏到歌单',
                      style: const TextStyle(
                          color: vinylInk,
                          fontSize: 22,
                          fontWeight: FontWeight.w600))),
              IconButton(
                  tooltip: '添加歌单',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () async {
                    final name = await showAddBilibiliPlaylist(context,
                        localOnly: trackId != null);
                    if (name != null && context.mounted) {
                      Navigator.pop(context, name);
                    }
                  }),
            ])),
        Expanded(
            child: ref.watch(playlistNamesProvider).when(
                  data: (allNames) {
                    final names = allNames
                        .where((name) => !importedNames.contains(name))
                        .toList();
                    return names.isEmpty
                        ? const Center(
                            child: Icon(Icons.library_music_outlined,
                                size: 48, color: vinylOlive))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            itemCount: names.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final name = names[index];
                              final ids =
                                  ref.watch(playlistIdsNotifierProvider(name));
                              final saved =
                                  trackId != null && ids.contains(trackId);
                              return Material(
                                  color: Colors.white.withOpacity(.7),
                                  borderRadius: BorderRadius.circular(18),
                                  child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 18, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18)),
                                      leading: Icon(
                                          name == 'favorite'
                                              ? Icons.favorite_rounded
                                              : Icons.album_rounded,
                                          color: vinylOlive),
                                      title: Text(
                                          name == 'favorite' ? '我喜欢的' : name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: vinylInk,
                                              fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                          '${ids.length} 首歌曲${saved ? ' · 已收藏' : ''}'),
                                      trailing: Icon(
                                          trackId == null
                                              ? Icons.chevron_right_rounded
                                              : saved
                                                  ? Icons.check_rounded
                                                  : Icons.add_rounded,
                                          color: vinylOlive),
                                      onTap: () =>
                                          Navigator.of(context).pop(name)));
                            });
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                      child: IconButton(
                          tooltip: '重试',
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () =>
                              ref.invalidate(playlistNamesProvider))),
                )),
      ]),
    );
  }
}
