import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/repo/playlist_names.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/view/page/option/option.page.dart';
import 'package:listen2/src/widget/app_style.dart';
import '../search/search.page.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';
import '../playlist/playlist.dart';

class Home extends ConsumerWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistNamesProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 16, 20),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('LISTEN 2',
                    style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w700,
                        color: AppStyle.accent)),
                const SizedBox(height: 8),
                Text('我的唱片', style: Theme.of(context).textTheme.headlineMedium),
              ])),
          IconButton(
              tooltip: '设置',
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const Option())),
              icon: const Icon(Icons.tune_rounded)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const Search())),
              child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(children: [
                    Icon(Icons.search_rounded, color: AppStyle.accent),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text('搜索歌曲、歌手或视频',
                            style: TextStyle(
                                color: AppStyle.muted, fontSize: 14))),
                    Icon(Icons.arrow_forward_rounded,
                        size: 18, color: AppStyle.muted),
                  ])),
            )),
      ),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Row(children: [
            Expanded(
                child: Text('唱片收藏',
                    style: Theme.of(context).textTheme.titleMedium)),
            Text('${playlists.valueOrNull?.length ?? 0} 个歌单',
                style: Theme.of(context).textTheme.bodyMedium),
          ])),
      Expanded(
          child: playlists.when(
        data: (names) => names.isEmpty
            ? const EmptyState(
                icon: Icons.library_music_rounded,
                title: '收藏你的音乐',
                message: '从搜索开始，把喜欢的音乐加入歌单')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: names.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => PlaylistItem(name: names[i])),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => EmptyState(
            icon: Icons.error_outline_rounded,
            title: '歌单加载失败',
            message: '请稍后重试',
            action: TextButton(
                onPressed: () => ref.invalidate(playlistNamesProvider),
                child: const Text('重试'))),
      )),
    ]);
  }
}

class PlaylistItem extends ConsumerWidget {
  const PlaylistItem({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = name == 'favorite';
    final count = ref.watch(playlistIdsNotifierProvider(name)).length;
    return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PlaylistPage(playlistName: name))),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                SizedBox(
                    width: 62,
                    height: 62,
                    child: VinylRecord(
                        playing: false,
                        cover: ColoredBox(
                            color: favorite
                                ? const Color(0xFFDBBE7E)
                                : const Color(0xFFA6B196),
                            child: Icon(
                                favorite
                                    ? Icons.favorite_rounded
                                    : Icons.music_note_rounded,
                                color: Colors.white,
                                size: 14)))),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(favorite ? '我喜欢的音乐' : name,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text('$count 首歌曲',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ])),
                if (!favorite)
                  IconButton(
                      tooltip: '删除歌单',
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppStyle.muted, size: 22),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                                    title: const Text('删除歌单？'),
                                    content: Text('确定删除「$name」吗？'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('取消')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('删除'))
                                    ]));
                        if (confirmed == true) {
                          ref.read(playlistNamesProvider.notifier).delete(name);
                        }
                      }),
                const Icon(Icons.chevron_right_rounded, color: AppStyle.muted),
              ])),
        ));
  }
}
