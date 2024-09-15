import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme, Colors, Divider, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/stateful/favorite.dart';
import 'package:listen2/src/provider/stateful/player.dart';
import 'package:listen2/src/provider/stateful/track.dart';
import 'package:listen2/src/widget/button/button.dart';
import 'package:listen2/src/widget/popup.dart';
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

final popupTrackProvider = StateProvider<Track?>((ref) {
  return null;
});

class FavoratePage extends ConsumerWidget {
  final _favoActionPopupKey = GlobalKey<PopupState>();

  FavoratePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var tracks = ref.watch(favoriteTracksProvider);

    var w = tracks.when(
        data: (value) {
          return Column(
            children: [
              Button(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('return')),
              Expanded(
                  child: ListView.separated(
                      shrinkWrap: true,
                      separatorBuilder: (context, index) => const Divider(
                            color: Colors.black26,
                            height: 1,
                          ),
                      itemCount: value.length,
                      itemBuilder: (context, index) {
                        return _favoriteItem(index, value[index], context, ref);
                      })),
            ],
          );
        },
        error: (err, traceback) {
          print(err);
          print(traceback);
          return const Text('err');
        },
        loading: () => const Text('loading'));

    final track = ref.watch(popupTrackProvider);
    return Stack(children: [
      Container(color: Colors.white, child: w),
      Popup(
        track == null
            ? Container()
            : Center(
                child: Button(
                  onTap: () {
                    ref
                        .read(favoriteIdsNotifierProvider.notifier)
                        .toggle(track.bvid);
                    _favoActionPopupKey.currentState!.toggle();
                  },
                  child: Text('取消收藏'),
                ),
              ),
        key: _favoActionPopupKey,
      ),
    ]);
  }

  Widget _favoriteItem(
      int index, Track track, BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(playerStateNotifierProvider.notifier).playTrack(track);
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
                // print(track.bvid);
                // ref
                //     .read(favoriteIdsNotifierProvider.notifier)
                //     .toggle(track.bvid);
                // ref.read(popupTrackProvider.s);
                ref.read(popupTrackProvider.notifier).state = track;
                _favoActionPopupKey.currentState!.toggle();
              },
              child: const Icon(
                Icons.list,
                size: 40,
              ),
            ),
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
