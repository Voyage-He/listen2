import 'dart:ffi';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme, Colors, Divider, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/repo/playlist_names.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/provider/global/player.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:listen2/src/widget/button/button.dart';
import 'package:listen2/src/widget/input/input.dart';
import 'package:listen2/src/widget/popup.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'playlist.g.dart';

@riverpod
Future<List<Track>> playlistTracks(
    PlaylistTracksRef ref, String playlistName) async {
  List<String> ids =
      await ref.watch(playlistIdsNotifierProvider(playlistName).future);

  List<Future<Track>> futures = [];

  for (final id in ids) {
    futures.add(ref.watch(trackProvider(id).future));
  }

  return await Future.wait(futures);
}

final popupTrackProvider = StateProvider<Track?>((ref) {
  return null;
});

@riverpod
bool reverseSort(ReverseSortRef ref) {
  return false;
}

@Riverpod(keepAlive: true)
class AddPlaylistNameNotifier extends _$AddPlaylistNameNotifier {
  @override
  String build() {
    return '';
  }

  update(String value) {
    print('update:$value');
    state = value;
  }
}

class PlaylistPage extends ConsumerWidget {
  final _actionPopupKey = GlobalKey<PopupState>();
  final _playlistSettingPopupKey = GlobalKey<PopupState>();
  final _addPlaylistPopupKey = GlobalKey<PopupState>();

  PlaylistPage({super.key, required this.playlistName});
  final String playlistName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var tracks = ref.watch(playlistTracksProvider(playlistName));

    var main = tracks.when(
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
                        return _trackItem(index, value[index], context, ref);
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
      Expanded(child: Container(color: Colors.white, child: main)),
      Popup(
        track == null
            ? Container()
            : Center(
                child: Column(
                  children: [
                    Button(
                      onTap: () {
                        ref
                            .read(playlistIdsNotifierProvider(playlistName)
                                .notifier)
                            .toggle(track.bvid);
                        _actionPopupKey.currentState!.toggle();
                      },
                      child: Text('取消收藏'),
                    ),
                    Button(
                      onTap: () {
                        _actionPopupKey.currentState!.toggle();
                        _playlistSettingPopupKey.currentState!.toggle();
                      },
                      child: Text('加入歌单'),
                    ),
                  ],
                ),
              ),
        key: _actionPopupKey,
      ),
      _playlistSettingPopup(ref, track),
      _addPlaylistPopup(ref, track),
    ]);
  }

  Widget _trackItem(
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
                _actionPopupKey.currentState!.toggle();
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

  Widget _playlistSettingPopup(WidgetRef ref, Track? track) {
    final playlistNames = ref.watch(playlistNamesProvider);
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
                      _addPlaylistPopupKey.currentState!.toggle();
                    },
                    child: Text('新建歌单'),
                  ),
                  if (playlistNames.valueOrNull?.isNotEmpty ?? false)
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlistNames.valueOrNull!.length,
                      itemBuilder: (context, index) {
                        final name = playlistNames.valueOrNull![index];
                        final isCollected = ref
                            .watch(playlistIdsNotifierProvider(name))
                            .valueOrNull!
                            .contains(track!.bvid);
                        return Button(
                          onTap: () {
                            ref
                                .read(playlistIdsNotifierProvider(name).notifier)
                                .toggle(track!.bvid);
                          },
                          color: isCollected ? Colors.grey : Colors.blue,
                          child: Row(
                            children: [
                              Text(playlistNames.valueOrNull![index]),
                              Icon(isCollected ? Icons.check : Icons.add),
                            ],
                          ),
                        );
                      },
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
                      debugPrint(
                          'a' + ref.read(addPlaylistNameNotifierProvider));
                    },
                    onDone: () {
                      final name = ref.read(addPlaylistNameNotifierProvider);
                      ref.read(playlistNamesProvider.notifier).add(name);
                      ref
                          .read(playlistIdsNotifierProvider(name).notifier)
                          .add(track!.bvid);
                      _addPlaylistPopupKey.currentState!.toggle();
                    },
                  ),
                  Button(
                    onTap: () {
                      final name = ref.read(addPlaylistNameNotifierProvider);
                      ref.read(playlistNamesProvider.notifier).add(name);
                      ref
                          .read(playlistIdsNotifierProvider(name).notifier)
                          .add(track!.bvid);
                      _addPlaylistPopupKey.currentState!.toggle();
                    },
                    child: Text('确认'),
                  ),
                ],
              ),
            ),
      key: _addPlaylistPopupKey,
    );
  }
}
