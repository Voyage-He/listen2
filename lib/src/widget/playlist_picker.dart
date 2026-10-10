import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/repo/playlist_names.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';
import 'package:listen2/src/widget/add_bilibili_playlist.dart';

class PlaylistPicker extends ConsumerWidget {
  const PlaylistPicker({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
        top: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 16, 18),
              child: Row(children: [
                const Expanded(
                    child: Text('歌单',
                        style: TextStyle(
                            color: vinylInk,
                            fontSize: 22,
                            fontWeight: FontWeight.w600))),
                IconButton(
                    tooltip: '添加歌单',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () async {
                      final name = await showAddBilibiliPlaylist(context);
                      if (name != null && context.mounted) {
                        Navigator.pop(context, name);
                      }
                    }),
              ])),
          Expanded(
              child: ref.watch(playlistNamesProvider).when(
                    data: (names) => names.isEmpty
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
                              final count = ref
                                  .watch(playlistIdsNotifierProvider(name))
                                  .length;
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
                                      subtitle: Text('$count 首歌曲'),
                                      trailing: const Icon(
                                          Icons.chevron_right_rounded,
                                          color: vinylOlive),
                                      onTap: () =>
                                          Navigator.of(context).pop(name)));
                            }),
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
