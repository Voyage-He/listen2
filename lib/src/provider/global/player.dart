import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:audio_session/audio_session.dart';
import 'package:hive/hive.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:listen2/src/provider/global/current_playlist.dart';
import 'package:listen2/src/ref_extensions.dart';

part 'player.g.dart';

class PlayerState {
  ap.PlayerState state;
  Duration now;
  Duration length;
  Track? track;

  PlayerState(
      {this.state = ap.PlayerState.stopped,
      this.now = Duration.zero,
      this.length = Duration.zero,
      this.track});

  PlayerState copyWith(
      {ap.PlayerState? state, Duration? length, Duration? now, Track? track}) {
    return PlayerState(
        state: state ?? this.state,
        length: length ?? this.length,
        now: now ?? this.now,
        track: track ?? this.track);
  }
}

/// Add background ablility to [AudioPlayers.AudioPlayer].
class AudioHandler extends audio_service.BaseAudioHandler with audio_service.QueueHandler, audio_service.SeekHandler {
  final player = ap.AudioPlayer();
  
  // 播放列表状态
  CurrentPlaylistState? _playlistState;
  // 当前播放的曲目
  Track? _currentTrack;
  // 存储引用
  Box<CurrentPlaylistState>? _playlistBox;
  // 播放曲目的回调函数
  late Future<void> Function(String) playTrackById;
  
  AudioHandler() {
    // 初始化播放状态
    playbackState.add(audio_service.PlaybackState(
      playing: false,
      controls: [
        audio_service.MediaControl.skipToPrevious,
        audio_service.MediaControl.pause,
        audio_service.MediaControl.play,
        audio_service.MediaControl.skipToNext,
      ],
      systemActions: const {
        audio_service.MediaAction.seek,
        audio_service.MediaAction.seekForward,
        audio_service.MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: audio_service.AudioProcessingState.ready,
    ));
    
    // 监听播放状态变化
    player.onPlayerStateChanged.listen((state) {
      playbackState.add(playbackState.value.copyWith(
        playing: state == ap.PlayerState.playing,
      ));
      
      // 处理播放完成事件
      if (state == ap.PlayerState.completed) {
        _onPlaybackCompleted();
      }
    });
  }
  
  // 设置播放列表存储
  void setPlaylistBox(Box<CurrentPlaylistState> box) {
    _playlistBox = box;
    // 加载保存的播放列表状态
    _playlistState = box.get('default', defaultValue: const CurrentPlaylistState(index: 0, playlist: []));
  }
  
  // 播放完成时处理
  void _onPlaybackCompleted() {
    if (_playlistState == null || !_playlistState!.hasNext) return;
    
    // 更新到下一首
    final newState = _playlistState!.playNext();
    
    // 设置新的播放列表状态
    setPlaylist(newState.index, newState.playlist);
    
    // 通知UI更新
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      updatePosition: Duration.zero,
    ));
    
    // 自动播放下一首
    if (newState.playlist.isNotEmpty) {
      Future.microtask(() async {
        await playTrackById(newState.currentTrackId);
      });
    }
  }
  
  // 设置当前播放的曲目
  void setCurrentTrack(Track track) {
    _currentTrack = track;
    // 更新媒体信息
    mediaItem.add(audio_service.MediaItem(
      id: track.bvid,
      title: track.title,
      artist: track.singer,
      artUri: Uri.parse(track.pictureUrl),
    ));
  }
  
  // 设置播放列表
  void setPlaylist(int index, List<String> playlist) {
    final newPlaylist = CurrentPlaylistState(
      index: index, 
      playlist: playlist
    );
    _playlistState = newPlaylist;
    
    // 保存状态
    if (_playlistBox != null) {
      _playlistBox!.put('default', newPlaylist);
    }
  }
  
  // 获取当前播放列表状态
  CurrentPlaylistState? getPlaylistState() {
    return _playlistState;
  }
  
  @override
  Future<void> play() => player.resume();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> stop() => player.stop();
  
  @override
  Future<void> skipToNext() async {
    if (_playlistState == null || !_playlistState!.hasNext) return;
    
    final newState = _playlistState!.playNext();
    setPlaylist(newState.index, newState.playlist);
    await playTrackById(newState.currentTrackId);
  }
  
  @override
  Future<void> skipToPrevious() async {
    if (_playlistState == null || _playlistState!.index <= 0) return;
    
    // 创建新的播放列表状态，索引减1
    final newState = CurrentPlaylistState(
      index: _playlistState!.index - 1,
      playlist: _playlistState!.playlist,
    );
    
    // 设置新的播放列表状态
    setPlaylist(newState.index, newState.playlist);
    
    // 播放上一首
    await playTrackById(newState.currentTrackId);
  }


  @override
  Future<void> dispose() async {
    debugPrint('info: audiohandler disposal');
    await player.dispose();
  }
}

@Riverpod(keepAlive: true)
class PlayerStateNotifier extends _$PlayerStateNotifier {
  late AudioHandler _audioHandler; // Local AudioHandler class, not from audio_service
  late StreamSubscription _playerStateChangeSubscription;
  late StreamSubscription _durationChangeSubscription;
  late StreamSubscription _positionChangeSubscription;
  late StreamSubscription _interruptionEventSubscription;
  bool _isInterrupt = false;

  @override
  PlayerState build() {
    _audioHandler = ref.watch(audioHandlerProvider).requireValue as AudioHandler;

    // 设置播放列表存储
    final playlistBox = ref.storage.custom["current_playlist_state"] as Box<CurrentPlaylistState>;
    _audioHandler.setPlaylistBox(playlistBox);

    // 设置音频焦点
    const audioFocusNone = ap.AudioContext(
        android: ap.AudioContextAndroid(audioFocus: ap.AndroidAudioFocus.none));
    _audioHandler.player.setAudioContext(audioFocusNone);

    // 监听播放状态变化
    _playerStateChangeSubscription =
        _audioHandler.player.onPlayerStateChanged.listen((e) async {
      // ignore if state is same, audioplayer will emit same state
      if (e == state.state) return;
      debugPrint('listened_state$e');
      state = state.copyWith(state: e);
      if (e == ap.PlayerState.playing) {
        _audioHandler.playbackState
            .add(_audioHandler.playbackState.value.copyWith(playing: true));
      } else {
        _audioHandler.playbackState
            .add(_audioHandler.playbackState.value.copyWith(playing: false));
      }
    });

    // 监听时长变化
    _durationChangeSubscription =
        _audioHandler.player.onDurationChanged.listen((e) async {
      state = state.copyWith(length: e);
    });

    // 监听播放位置变化
    _positionChangeSubscription =
        _audioHandler.player.onPositionChanged.listen((e) async {
      state = state.copyWith(now: e);
    });

    // 监听音频中断
    AudioSession.instance.then((session) {
      _interruptionEventSubscription =
          session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          if (state.state == ap.PlayerState.playing) {
            await pause();
            _isInterrupt = true;
          }
        } else {
          if (!_isInterrupt) return;
          await resume();
          _isInterrupt = false;
        }
      });
    });

    // 资源释放
    ref.onDispose(() {
      debugPrint('info: call player disposal');
      _positionChangeSubscription.cancel();
      _durationChangeSubscription.cancel();
      _playerStateChangeSubscription.cancel();
      _interruptionEventSubscription.cancel();
      _audioHandler.dispose();
    });

    // 初始化播放列表
    final playlistState = _audioHandler.getPlaylistState();
    if (playlistState != null && playlistState.playlist.isNotEmpty) {
      // 如果有保存的播放列表，尝试播放当前曲目
      Future.microtask(() {
        playTrackById(playlistState.currentTrackId);
      });
    }

    return PlayerState();
  }

  Future<void> playTrack(Track track) async {
    debugPrint('play_track${track.title}');

    await _audioHandler.player.release();

    final session = await AudioSession.instance;
    if (!(await session.setActive(true))) return;

    var bytes = await ref.read(trackBytesProvider(track).future);
    await _audioHandler.player.play(ap.BytesSource(bytes));
    
    // 更新AudioHandler中的当前曲目
    _audioHandler.setCurrentTrack(track);
    state = state.copyWith(track: track);
  }

  Future<void> playTrackById(String trackId) async {
    if (trackId.isEmpty) {
      state = PlayerState();
      return;
    }
    final track = await ref.read(trackProvider(trackId).future);
    await playTrack(track);
    
    // 实现AudioHandler中的playTrackById方法
    _audioHandler.playTrackById = (String id) async {
      if (id.isEmpty) return;
      final trackToPlay = await ref.read(trackProvider(id).future);
      await playTrack(trackToPlay);
    };
  }
  
  // 播放指定曲目和播放列表
  Future<void> playWithPlaylist(String trackId, List<String> playlistTrackIds) async {
    // 计算索引
    final index = playlistTrackIds.indexOf(trackId);
    if (index < 0) return; // 如果曲目不在列表中，不执行操作
    
    // 设置播放列表
    _audioHandler.setPlaylist(index, playlistTrackIds);
    // 播放当前曲目
    await playTrackById(trackId);
  }

  Future<void> pause() async {
    await _audioHandler.player.pause();
  }

  Future<void> resume() async {
    if (state.state == ap.PlayerState.completed) return;

    final session = await AudioSession.instance;
    if (!(await session.setActive(true))) return;

    await _audioHandler.player.resume();
  }

  Future<void> seek(Duration position) async {
    debugPrint('seeking to $position');
    await _audioHandler.player.seek(position);
  }
  
  // 播放下一首
  Future<void> playNext() async {
    final playlistState = _audioHandler.getPlaylistState();
    if (playlistState == null || !playlistState.hasNext) return;
    
    final newState = playlistState.playNext();
    _audioHandler.setPlaylist(newState.index, newState.playlist);
    await playTrackById(newState.currentTrackId);
  }
  
  // 播放上一首
  Future<void> playPrevious() async {
    final playlistState = _audioHandler.getPlaylistState();
    if (playlistState == null || playlistState.index <= 0) return;
    
    // 创建新的播放列表状态，索引减1
    final newState = CurrentPlaylistState(
      index: playlistState.index - 1,
      playlist: playlistState.playlist,
    );
    
    // 设置新的播放列表状态
    _audioHandler.setPlaylist(newState.index, newState.playlist);
    
    // 播放上一首
    await playTrackById(newState.currentTrackId);
  }
}

@Riverpod(keepAlive: true)
Future<audio_service.AudioHandler> audioHandler(AudioHandlerRef ref) async {
  // 初始化音频会话
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  
  // 初始化音频服务
  final audioHandler = audio_service.AudioService.init(
    builder: () => AudioHandler(),
    config: const audio_service.AudioServiceConfig(
      androidStopForegroundOnPause: true,
      androidNotificationChannelId: 'com.ryanheise.audioserviceexample.channel.audio',
      androidNotificationChannelName: 'Listen2 Audio Service',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
      notificationColor: Color(0xFF2196F3),
    ),
  );

  return audioHandler;
}
