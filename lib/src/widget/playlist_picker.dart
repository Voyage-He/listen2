import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/repo/bilibili_playlists.dart';
import 'package:listen2/src/provider/repo/playlist_names.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';
import 'package:listen2/src/widget/add_bilibili_playlist.dart';

class PlaylistPicker extends ConsumerStatefulWidget {
  const PlaylistPicker({super.key, this.trackId});
  final String? trackId;

  @override
  ConsumerState<PlaylistPicker> createState() => _PlaylistPickerState();
}

class _PlaylistPickerState extends ConsumerState<PlaylistPicker> {
  String? _changingName;
  String? _message;
  bool _failed = false;

  Future<void> _setSaved(String name, bool saved) async {
    final trackId = widget.trackId;
    if (trackId == null || _changingName != null) return;
    setState(() {
      _changingName = name;
      _message = null;
      _failed = false;
    });
    try {
      final playlist = ref.read(playlistIdsNotifierProvider(name).notifier);
      if (saved) {
        await playlist.add(trackId);
      } else {
        await playlist.delete(trackId);
      }
      if (!mounted) return;
      final title = name == 'favorite' ? '我喜欢的' : name;
      setState(() => _message = saved ? '已收藏到「$title」' : '已从「$title」移除');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = saved ? '收藏失败，请重试' : '取消收藏失败，请重试';
        _failed = true;
      });
    } finally {
      if (mounted) setState(() => _changingName = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackId = widget.trackId;
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
                  onPressed: _changingName != null
                      ? null
                      : () async {
                          final name = await showAddBilibiliPlaylist(context,
                              localOnly: trackId != null);
                          if (name == null || !context.mounted) return;
                          if (trackId == null) {
                            Navigator.pop(context, name);
                          } else {
                            await _setSaved(name, true);
                          }
                        }),
            ])),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Semantics(
              liveRegion: true,
              child: Text(_message!,
                  style: TextStyle(
                      color: _failed
                          ? Theme.of(context).colorScheme.error
                          : vinylOlive,
                      fontSize: 13,
                      height: 1.5)),
            ),
          ),
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
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18)),
                                      leading: Icon(
                                          name == 'favorite'
                                              ? Icons.favorite_rounded
                                              : Icons.album_rounded,
                                          color: vinylOlive),
                                      title: Text(name == 'favorite' ? '我喜欢的' : name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: vinylInk,
                                              fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                          '${ids.length} 首歌曲${saved ? ' · 已收藏' : ''}'),
                                      trailing: _changingName == name
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: vinylOlive))
                                          : saved
                                              ? IconButton(
                                                  tooltip: '取消收藏',
                                                  onPressed:
                                                      _changingName != null
                                                          ? null
                                                          : () => _setSaved(
                                                              name, false),
                                                  color: vinylOlive,
                                                  icon: const Icon(
                                                      Icons
                                                          .remove_circle_outline_rounded,
                                                      size: 24),
                                                )
                                              : Icon(
                                                  trackId == null
                                                      ? Icons.chevron_right_rounded
                                                      : Icons.add_rounded,
                                                  color: vinylOlive),
                                      onTap: _changingName != null
                                          ? null
                                          : trackId == null
                                              ? () => Navigator.of(context).pop(name)
                                              : () => _setSaved(name, !saved)));
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
