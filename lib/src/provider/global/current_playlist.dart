import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:listen2/src/provider/global/player.dart';
import 'package:listen2/src/ref_extensions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_playlist.g.dart';

@HiveType(typeId: 2)
class CurrentPlaylistState {
  @HiveField(0)
  final int index;
  @HiveField(1)
  final List<String> playlist;
  const CurrentPlaylistState({required this.index, required this.playlist});

  String get currentTrackId => playlist[index];

  bool get hasNext => index < playlist.length - 1;

  CurrentPlaylistState playNext() {
    if (!hasNext) return this;
    return CurrentPlaylistState(index: index + 1, playlist: playlist);
  }

  CurrentPlaylistState insertTrackId(String trackId) {
    return CurrentPlaylistState(index: index, playlist: playlist..insert(index + 1, trackId));
  }
}

@Riverpod(keepAlive: true)
class CurrentPlaylistNotifier extends _$CurrentPlaylistNotifier {
  bool initilized = false;

  @override
  CurrentPlaylistState build() {
    final playerBackState = ref.watch(playerStateNotifierProvider.select((state) => state.state));
    final currentPlaylistState = ref.storage.custom["current_playlist_state"]!.get('default', defaultValue: const CurrentPlaylistState(index: 0, playlist: []));
    debugPrint("current play list provider build");
    debugPrint('playerBackState: $playerBackState');
    if (playerBackState == ap.PlayerState.completed) {
      debugPrint('currentPlaylistState: ${currentPlaylistState.hasNext}');
      if (currentPlaylistState.hasNext) {
        final newState = currentPlaylistState.playNext();
        ref.storage.custom["current_playlist_state"]!.put('default', newState);
        return load();
      } else {
        return currentPlaylistState;
      }
    } else if (playerBackState == ap.PlayerState.playing) {
      return currentPlaylistState;
    }

    if (initilized) return currentPlaylistState;
    initilized = true;
    return load();
    // TODO fix: this load() cause play call twice when play next automatically
  }

  void play(String trackId, List<String> playlistTrackIds) {
    final newPlaylist =
        CurrentPlaylistState(index: playlistTrackIds.indexOf(trackId), playlist: playlistTrackIds);
    ref.storage.custom["current_playlist_state"]!.put('default', newPlaylist);
    load();
  }

  void setNext(String trackId) {
    ref.storage.custom["current_playlist_state"]!.put('default', state.insertTrackId(trackId));
    load();
  }

  CurrentPlaylistState load() {
    final currentPlaylistState = ref.storage.custom["current_playlist_state"]!.get(
        'default',
        defaultValue: const CurrentPlaylistState(index: 0, playlist: []));

    if (currentPlaylistState.playlist.isEmpty) return currentPlaylistState;
    if (currentPlaylistState.currentTrackId ==
        ref.read(playerStateNotifierProvider.notifier).state.track?.bvid) {
      return currentPlaylistState;
    }

    ref
        .read(playerStateNotifierProvider.notifier)
        .playTrackById(currentPlaylistState.currentTrackId);
        debugPrint('load call time');
    return currentPlaylistState;
  }
}
