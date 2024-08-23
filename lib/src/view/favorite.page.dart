import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme, Colors, Divider, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/stateful/favorite.dart';
import 'package:listen2/src/provider/stateful/track.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'favorite.page.g.dart';

@riverpod
Future<List<Track>> favoriteTracks(FavoriteTracksRef ref) async {
  List<String> ids = await ref.watch(favoriteIdsNotifierProvider.future);

  List<Future<Track>> futures = [];

  for (final id in ids) {
    futures.add(ref.watch(trackProvider(id).future));
  }

  return await Future.wait(futures);
}

class FavoratePage extends ConsumerWidget {
  const FavoratePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 收藏bvid（甚至track完整信息）的本地存储，以及收藏页面列表展示
    var tracks = ref.watch(favoriteTracksProvider);
    print(tracks);

    var w = tracks.when(
        data: (value) {
          print(value);
          return Column(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop(context);
                },
                child: Text("return"),
              ),
              ListView.separated(
                  shrinkWrap: true,
                  separatorBuilder: (context, index) => const Divider(
                        color: Colors.black26,
                        height: 1,
                      ),
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    return _favoriteItem(index, value[index], context, ref);
                  }),
            ],
          );
        },
        error: (err, traceback) {
          print(err);
          print(traceback);
          return const Text('err');
        },
        loading: () => const Text('loading'));

    return Container(color: Colors.white, child: w);
  }

  Widget _favoriteItem(
      int index, Track track, BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(currentTrackProvider.notifier).update(track);
      },
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                child: Text((index + 1).toString())),
            Expanded(
              child: _trackInfo(context, track),
            ),
            GestureDetector(
                onTap: () {
                  // ref
                  //     .read(favoriteIdsNotifierProvider.notifier)
                  //     .toggle(track.bvid);
                },
                child: const Icon(Icons.favorite_outlined,
                    color: Colors.redAccent)),
          ],
        ),
      ),
    );
  }

  Widget _trackInfo(BuildContext context, Track? track) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(track?.title ?? '', style: Theme.of(context).textTheme.bodyLarge),
        Text(track?.singer ?? '', style: Theme.of(context).textTheme.bodyMedium)
      ],
    );
  }
}
