import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:listen2/src/provider/global/player.dart';
import 'package:listen2/src/ref_extensions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:listen2/src/provider/repo/track.dart';

part 'current_playlist.g.dart';

@HiveType(typeId: 2)
class CurrentPlaylistState {
  @HiveField(0)
  final int index;
  @HiveField(1)
  final List<String> playlist;
  const CurrentPlaylistState({this.index = 0, this.playlist = const []});

  String get currentTrackId {
    if (playlist.isEmpty) return "";
    return playlist[index];
  }

  bool get hasNext {
    return playlist.isNotEmpty && index < playlist.length - 1;
  }

  CurrentPlaylistState playNext() {
    if (!hasNext) return this;
    return copyWith(index: index + 1);
  }

  CurrentPlaylistState insertTrackId(String trackId) {
    if (playlist.isEmpty) {
      return copyWith(playlist: [trackId]);
    }
    
    final newPlaylist = List<String>.from(playlist);
    newPlaylist.insert(index + 1, trackId);
    return copyWith(playlist: newPlaylist);
  }
  
  CurrentPlaylistState copyWith({
    int? index,
    List<String>? playlist,
  }) {
    return CurrentPlaylistState(
      index: index ?? this.index,
      playlist: playlist ?? this.playlist,
    );
  }
}

@Riverpod(keepAlive: true)
class CurrentPlaylistNotifier extends _$CurrentPlaylistNotifier {
  // 使用本地AudioHandler类型而不是audio_service.AudioHandler
  late AudioHandler _audioHandler;

  @override
  CurrentPlaylistState build() {
    // 获取AudioHandler实例并进行类型转换
    _audioHandler = ref.watch(audioHandlerProvider).requireValue as AudioHandler;
    
    // 从AudioHandler获取播放列表状态
    final playlistState = _audioHandler.getPlaylistState();
    if (playlistState != null) {
      return playlistState;
    }
    
    return CurrentPlaylistState(index: 0, playlist: []);
  }

  // 播放指定曲目和播放列表
  Future<void> playTrack(Track track, List<String> playlist) async {
    // 更新状态
    final index = playlist.indexOf(track.bvid);
    state = CurrentPlaylistState(
      index: index >= 0 ? index : 0,
      playlist: playlist,
    );
    
    // 设置AudioHandler的播放列表
    _audioHandler.setPlaylist(state.index, playlist);
    
    // 播放曲目
    await ref.read(playerStateNotifierProvider.notifier).playTrack(track);
  }

  // 通过ID播放指定曲目和播放列表
  Future<void> playTrackById(String trackId, List<String> playlist) async {
    // 更新状态
    final index = playlist.indexOf(trackId);
    state = CurrentPlaylistState(
      index: index >= 0 ? index : 0,
      playlist: playlist,
    );
    
    // 使用AudioHandler设置播放列表
    _audioHandler.setPlaylist(state.index, playlist);
    
    // 播放曲目
    await ref
        .read(playerStateNotifierProvider.notifier)
        .playTrackById(trackId);
  }

  // 设置下一首要播放的曲目
  Future<void> setNext(String trackId) async {
    // 获取新的播放列表状态
    final newState = state.insertTrackId(trackId);
    
    // 更新状态
    state = newState;
    
    // 更新AudioHandler的播放列表
    _audioHandler.setPlaylist(newState.index, newState.playlist);
  }

  // 播放下一首曲目
  Future<void> playNext() async {
    if (!state.hasNext) return;
    
    // 获取下一首曲目状态
    final newState = state.playNext();
    state = newState;
    
    // 更新AudioHandler的播放列表
    _audioHandler.setPlaylist(newState.index, newState.playlist);
    
    // 播放下一首曲目
    await ref
        .read(playerStateNotifierProvider.notifier)
        .playTrackById(newState.currentTrackId);
  }
  
  // 通过bvid播放指定曲目和播放列表
  Future<void> play(String bvid, List<String> playlist) async {
    // 与playTrackById方法相同，只是参数名不同
    await playTrackById(bvid, playlist);
  }
}
