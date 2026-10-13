import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/repo/bilibili_playlists.dart';
import 'package:listen2/src/provider/repo/playlist_names.dart';

/// Returns true when the songs are kept locally, false when the playlist is
/// removed from the app, and null when canceled or unsuccessful.
Future<bool?> showUnlinkBilibiliPlaylist(
    BuildContext context, WidgetRef ref, String name) async {
  var keepSongs = true;
  final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
                title: const Text('取消 Bilibili 关联？'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('「$name」将停止与 Bilibili 收藏夹同步。Bilibili 上的收藏夹和歌曲不受影响。'),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('保留为本地歌单'),
                      subtitle:
                          Text(keepSongs ? '保留现有歌曲，可在应用内自由整理' : '从应用移除这个歌单'),
                      value: keepSongs,
                      onChanged: (value) =>
                          setState(() => keepSongs = value ?? true)),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('返回')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, keepSongs),
                      child: const Text('取消关联')),
                ],
              )));
  if (result == null || !context.mounted) return null;
  try {
    if (result) {
      await ref.read(bilibiliPlaylistsProvider.notifier).remove(name);
    } else {
      await ref.read(playlistNamesProvider.notifier).delete(name);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result ? '已取消关联，歌曲保留为本地歌单' : '已取消关联并从应用移除歌单')));
    }
    return result;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('取消关联失败，请重试')));
    }
    return null;
  }
}
