import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/repo/bilibili_playlists.dart';
import 'package:listen2/src/provider/repo/playlist_names.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';
import 'package:listen2/src/widget/add_bilibili_playlist.dart';
import 'package:listen2/src/view/page/option/bilibili_account.page.dart';
import 'package:listen2/src/widget/bilibili_logo.dart';
import 'package:listen2/src/provider/repo/bilibili_account.dart';
import 'package:music_api/music_api.dart';

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
  (String, bool)? _loginTarget;

  Future<void> _login() async {
    final target = _loginTarget;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BilibiliAccountPage()));
    if (!mounted || target == null) return;
    if (ref.read(bilibiliAccountClientProvider).user != null) {
      await _setSaved(target.$1, target.$2);
    }
  }

  Future<void> _setSaved(String name, bool saved) async {
    final trackId = widget.trackId;
    if (trackId == null || _changingName != null) return;
    setState(() {
      _changingName = name;
      _message = null;
      _failed = false;
      _loginTarget = null;
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
      final remote = ref.read(bilibiliPlaylistsProvider).containsKey(name);
      setState(() => _message = saved
          ? '已收藏到${remote ? ' Bilibili ' : ''}「$title」'
          : '已从${remote ? ' Bilibili ' : ''}「$title」移除');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error is BilibiliApiException
            ? error.message
            : saved
                ? '收藏失败，请重试'
                : '取消收藏失败，请重试';
        if (error is BilibiliApiException && error.code == -101) {
          _loginTarget = (name, saved);
          ref.read(bilibiliAccountProvider.notifier).sessionExpired();
        }
        _failed = true;
      });
    } finally {
      if (mounted) setState(() => _changingName = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackId = widget.trackId;
    final importedNames = ref.watch(bilibiliPlaylistsProvider).keys.toSet();
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
                  tooltip: 'Bilibili 收藏夹',
                  icon: const BilibiliLogo(size: 26),
                  onPressed: _changingName != null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              BilibiliAccountPage(trackId: trackId)))),
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
        if (_loginTarget != null)
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: TextButton.icon(
                  onPressed: _login,
                  icon: const Icon(Icons.qr_code_rounded),
                  label: const Text('扫码登录后继续'))),
        if (trackId != null && importedNames.isNotEmpty)
          const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text('Bilibili 收藏夹中的收藏操作会同步到平台。',
                  style: TextStyle(color: vinylOlive, fontSize: 12))),
        Expanded(
            child: ref.watch(playlistNamesProvider).when(
                  data: (allNames) {
                    final names = allNames;
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
                              final remote = importedNames.contains(name);
                              return Material(
                                  color: Colors.white.withOpacity(.7),
                                  borderRadius: BorderRadius.circular(18),
                                  child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18)),
                                      leading: remote
                                          ? const BilibiliLogo()
                                          : Icon(
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
                                          '${ids.length} 首歌曲${remote ? ' · Bilibili 收藏夹' : ''}${saved ? ' · 已收藏' : ''}'),
                                      trailing: _changingName == name
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: vinylOlive))
                                          : saved
                                              ? IconButton(
                                                  tooltip: remote
                                                      ? '从 Bilibili 取消收藏'
                                                      : '取消收藏',
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
