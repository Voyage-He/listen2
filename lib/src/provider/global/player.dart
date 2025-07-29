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
      // 更新播放状态
      final isPlaying = state == ap.PlayerState.playing;
      
      // 更新播放状态
      playbackState.add(playbackState.value.copyWith(
        playing: isPlaying,
        // 确保处理状态正确
        processingState: isPlaying 
            ? audio_service.AudioProcessingState.ready 
            : (state == ap.PlayerState.completed 
                ? audio_service.AudioProcessingState.completed 
                : playbackState.value.processingState),
      ));
      
      // 处理播放完成事件
      if (state == ap.PlayerState.completed) {
        _onPlaybackCompleted();
      }
    });
    
    // 监听错误事件
    
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
      processingState: audio_service.AudioProcessingState.ready,
    ));
    
    // 自动播放下一首
    if (newState.playlist.isNotEmpty) {
      // 使用延迟较短的Future.delayed而不是microtask，确保音频焦点不会丢失
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          // 确保在播放前保持音频焦点
          final session = await AudioSession.instance;
          await session.configure(const AudioSessionConfiguration.music()
            .copyWith(androidAudioAttributes: const AndroidAudioAttributes(
              contentType: AndroidAudioContentType.music,
              usage: AndroidAudioUsage.media,
              flags: AndroidAudioFlags.audibilityEnforced,
            )));
          
          if (await session.setActive(true)) {
            // 设置处理状态为加载中
            playbackState.add(playbackState.value.copyWith(
              processingState: audio_service.AudioProcessingState.loading,
            ));
            
            await playTrackById(newState.currentTrackId);
          } else {
            debugPrint('无法激活音频会话');
          }
        } catch (e) {
          debugPrint('播放下一首时出错: $e');
        }
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
  Future<void> play() async {
    try {
      // 设置处理状态为加载中
      playbackState.add(playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.loading,
      ));
      
      // 确保音频会话激活
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music()
        .copyWith(androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
          flags: AndroidAudioFlags.audibilityEnforced,
        )));
      
      if (!(await session.setActive(true))) {
        debugPrint('无法激活音频会话');
        return;
      }
      
      await player.resume();
      
      // 更新播放状态
      playbackState.add(playbackState.value.copyWith(
        playing: true,
        processingState: audio_service.AudioProcessingState.ready,
      ));
    } catch (e) {
      debugPrint('播放时出错: $e');
      playbackState.add(playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.error,
      ));
    }
  }

  @override
  Future<void> pause() async {
    try {
      await player.pause();
      
      // 更新播放状态
      playbackState.add(playbackState.value.copyWith(
        playing: false,
      ));
    } catch (e) {
      debugPrint('暂停时出错: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      // 设置处理状态为缓冲中
      playbackState.add(playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.buffering,
      ));
      
      await player.seek(position);
      
      // 恢复处理状态
      playbackState.add(playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.ready,
        updatePosition: position,
      ));
    } catch (e) {
      debugPrint('跳转时出错: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await player.stop();
      
      // 更新播放状态
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: audio_service.AudioProcessingState.idle,
        updatePosition: Duration.zero,
      ));
    } catch (e) {
      debugPrint('停止时出错: $e');
    }
  }
  
  @override
  Future<void> skipToNext() async {
    try {
      if (_playlistState == null || !_playlistState!.hasNext) return;
      
      // 设置处理状态为加载中
      playbackState.add(playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.loading,
      ));
      
      final newState = _playlistState!.playNext();
      setPlaylist(newState.index, newState.playlist);
      
      // 确保音频会话激活
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music()
        .copyWith(androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
          flags: AndroidAudioFlags.audibilityEnforced,
        )));
      
      if (!(await session.setActive(true))) {
        debugPrint('无法激活音频会话');
        return;
      }
      
      await playTrackById(newState.currentTrackId);
    } catch (e) {
      debugPrint('跳转下一首时出错: $e');
      playbackState.add(playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.error,
      ));
    }
  }
  
  @override
  Future<void> skipToPrevious() async {
    try {
      if (_playlistState == null || _playlistState!.index <= 0) return;
      
      // 设置处理状态为加载中
      playbackState.add(playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.loading,
      ));
      
      // 创建新的播放列表状态，索引减1
      final newState = CurrentPlaylistState(
        index: _playlistState!.index - 1,
        playlist: _playlistState!.playlist,
      );
      
      // 确保音频会话激活
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music()
        .copyWith(androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
          flags: AndroidAudioFlags.audibilityEnforced,
        )));
      
      if (!(await session.setActive(true))) {
        debugPrint('无法激活音频会话');
        return;
      }
    
    // 设置新的播放列表状态
      setPlaylist(newState.index, newState.playlist);
      
      // 播放上一首
      await playTrackById(newState.currentTrackId);
    } catch (e) {
      debugPrint('跳转上一首时出错: $e');
      playbackState.add(playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.error,
      ));
    }
  }


  @override
  Future<void> dispose() async {
    try {
      debugPrint('info: audiohandler disposal');
      
      // 停止播放
      await stop();
      
      // 更新播放状态为空闲
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: audio_service.AudioProcessingState.idle,
        updatePosition: Duration.zero,
      ));
      
      // 释放音频会话
      final session = await AudioSession.instance;
      await session.setActive(false);
      
      // 释放播放器资源
      await player.dispose();
    } catch (e) {
      debugPrint('释放资源时出错: $e');
    }
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

    // 设置音频焦点为gain，确保应用能够获取和保持音频焦点
    const audioContext = ap.AudioContext(
        android: ap.AudioContextAndroid(
          audioFocus: ap.AndroidAudioFocus.gain,
          stayAwake: true,
          contentType: ap.AndroidContentType.music,
          usageType: ap.AndroidUsageType.media,
        )
    );
    _audioHandler.player.setAudioContext(audioContext);

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
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          // 确保在播放前保持音频焦点
          final session = await AudioSession.instance;
          await session.configure(const AudioSessionConfiguration.music()
            .copyWith(androidAudioAttributes: const AndroidAudioAttributes(
              contentType: AndroidAudioContentType.music,
              usage: AndroidAudioUsage.media,
              flags: AndroidAudioFlags.audibilityEnforced,
            )));
          
          if (await session.setActive(true)) {
            // 设置处理状态为加载中
            _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
              processingState: audio_service.AudioProcessingState.loading,
            ));
            
            await playTrackById(playlistState.currentTrackId);
          } else {
            debugPrint('无法激活音频会话');
          }
        } catch (e) {
          debugPrint('初始化播放列表时出错: $e');
        }
      });
    }

    return PlayerState();
  }

  Future<void> playTrack(Track track) async {
    debugPrint('play_track${track.title}');

    try {
      await _audioHandler.player.release();

      // 设置处理状态为加载中
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.loading,
      ));

      final session = await AudioSession.instance;
      // 配置音频会话以支持后台播放
      await session.configure(const AudioSessionConfiguration.music()
        .copyWith(androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
          flags: AndroidAudioFlags.audibilityEnforced,
        )));
      
      if (!(await session.setActive(true))) {
        debugPrint('无法激活音频会话');
        return;
      }

      var bytes = await ref.read(trackBytesProvider(track).future);
      
      // 设置处理状态为准备就绪
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.ready,
      ));
      
      await _audioHandler.player.play(ap.BytesSource(bytes));
      
      // 更新AudioHandler中的当前曲目
      _audioHandler.setCurrentTrack(track);
      state = state.copyWith(track: track);
      
      // 设置处理状态为播放中
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        playing: true,
        processingState: audio_service.AudioProcessingState.ready,
      ));
    } catch (e) {
      debugPrint('播放曲目时出错: $e');
      // 设置处理状态为错误
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.error,
      ));
    }
  }

  Future<void> playTrackById(String trackId) async {
    try {
      if (trackId.isEmpty) {
        state = PlayerState();
        return;
      }
      
      // 设置处理状态为加载中
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.loading,
      ));
      
      // 确保音频会话激活
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music()
        .copyWith(androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
          flags: AndroidAudioFlags.audibilityEnforced,
        )));
      
      if (!(await session.setActive(true))) {
        debugPrint('无法激活音频会话');
        return;
      }
      
      final track = await ref.read(trackProvider(trackId).future);
      await playTrack(track);
      
      // 实现AudioHandler中的playTrackById方法
      _audioHandler.playTrackById = (String id) async {
        try {
          if (id.isEmpty) return;
          
          // 设置处理状态为加载中
          _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
            processingState: audio_service.AudioProcessingState.loading,
          ));
          
          // 确保音频会话激活
          final session = await AudioSession.instance;
          await session.configure(const AudioSessionConfiguration.music()
            .copyWith(androidAudioAttributes: const AndroidAudioAttributes(
              contentType: AndroidAudioContentType.music,
              usage: AndroidAudioUsage.media,
              flags: AndroidAudioFlags.audibilityEnforced,
            )));
          
          if (!(await session.setActive(true))) {
            debugPrint('无法激活音频会话');
            return;
          }
          
          final trackToPlay = await ref.read(trackProvider(id).future);
          await playTrack(trackToPlay);
        } catch (e) {
          debugPrint('通过ID播放曲目时出错: $e');
          // 设置处理状态为错误
          _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
            processingState: audio_service.AudioProcessingState.error,
          ));
        }
      };
    } catch (e) {
      debugPrint('通过ID播放曲目时出错: $e');
      // 设置处理状态为错误
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.error,
      ));
    }
  }
  
  // 播放指定曲目和播放列表
  Future<void> playWithPlaylist(String trackId, List<String> playlistTrackIds) async {
    try {
      // 计算索引
      final index = playlistTrackIds.indexOf(trackId);
      if (index < 0) return; // 如果曲目不在列表中，不执行操作
      
      // 设置处理状态为加载中
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.loading,
      ));
      
      // 确保音频会话激活
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music()
        .copyWith(androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
          flags: AndroidAudioFlags.audibilityEnforced,
        )));
      
      if (!(await session.setActive(true))) {
        debugPrint('无法激活音频会话');
        return;
      }
      
      // 设置播放列表
      _audioHandler.setPlaylist(index, playlistTrackIds);
      // 播放当前曲目
      await playTrackById(trackId);
    } catch (e) {
      debugPrint('播放列表时出错: $e');
      // 设置处理状态为错误
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.error,
      ));
    }
  }

  Future<void> pause() async {
    try {
      // 更新播放状态
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        playing: false,
      ));
      
      await _audioHandler.player.pause();
    } catch (e) {
      debugPrint('暂停时出错: $e');
    }
  }

  Future<void> resume() async {
    if (state.state == ap.PlayerState.completed) return;

    try {
      // 设置处理状态为加载中
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.loading,
      ));
      
      final session = await AudioSession.instance;
      // 配置音频会话以支持后台播放
      await session.configure(const AudioSessionConfiguration.music()
        .copyWith(androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
          flags: AndroidAudioFlags.audibilityEnforced,
        )));
      
      if (!(await session.setActive(true))) {
        debugPrint('无法激活音频会话');
        return;
      }

      // 设置处理状态为准备就绪
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.ready,
      ));
      
      await _audioHandler.player.resume();
      
      // 设置处理状态为播放中
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        playing: true,
        processingState: audio_service.AudioProcessingState.ready,
      ));
    } catch (e) {
      debugPrint('恢复播放时出错: $e');
      // 设置处理状态为错误
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.error,
      ));
    }
  }

  Future<void> seek(Duration position) async {
    try {
      debugPrint('seeking to $position');
      
      // 设置处理状态为缓冲中
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.buffering,
      ));
      
      // 确保音频会话激活
      final session = await AudioSession.instance;
      if (!(await session.setActive(true))) {
        debugPrint('无法激活音频会话');
        return;
      }
      
      await _audioHandler.player.seek(position);
      
      // 恢复处理状态
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.ready,
        updatePosition: position,
      ));
    } catch (e) {
      debugPrint('跳转时出错: $e');
      // 设置处理状态为错误
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.error,
      ));
    }
  }
  
  // 播放下一首
  Future<void> playNext() async {
    try {
      final playlistState = _audioHandler.getPlaylistState();
      if (playlistState == null || !playlistState.hasNext) return;
      
      // 设置处理状态为加载中
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.loading,
      ));
      
      // 确保音频会话激活
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music()
        .copyWith(androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
          flags: AndroidAudioFlags.audibilityEnforced,
        )));
      
      if (!(await session.setActive(true))) {
        debugPrint('无法激活音频会话');
        return;
      }
      
      final newState = playlistState.playNext();
      _audioHandler.setPlaylist(newState.index, newState.playlist);
      await playTrackById(newState.currentTrackId);
    } catch (e) {
      debugPrint('播放下一首时出错: $e');
      // 设置处理状态为错误
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.error,
      ));
    }
  }
  
  // 播放上一首
  Future<void> playPrevious() async {
    try {
      final playlistState = _audioHandler.getPlaylistState();
      if (playlistState == null || playlistState.index <= 0) return;
      
      // 设置处理状态为加载中
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.loading,
      ));
      
      // 确保音频会话激活
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music()
        .copyWith(androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
          flags: AndroidAudioFlags.audibilityEnforced,
        )));
      
      if (!(await session.setActive(true))) {
        debugPrint('无法激活音频会话');
        return;
      }
      
      // 创建新的播放列表状态，索引减1
      final newState = CurrentPlaylistState(
        index: playlistState.index - 1,
        playlist: playlistState.playlist,
      );
      
      // 设置新的播放列表状态
      _audioHandler.setPlaylist(newState.index, newState.playlist);
      
      // 播放上一首
      await playTrackById(newState.currentTrackId);
    } catch (e) {
      debugPrint('播放上一首时出错: $e');
      // 设置处理状态为错误
      _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
        processingState: audio_service.AudioProcessingState.error,
      ));
    }
  }
}

@Riverpod(keepAlive: true)
Future<audio_service.AudioHandler> audioHandler(AudioHandlerRef ref) async {
  try {
    // 初始化音频会话
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music()
      .copyWith(androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
        flags: AndroidAudioFlags.audibilityEnforced,
      )));
    
    if (!(await session.setActive(true))) {
      debugPrint('无法激活音频会话');
    }
    
    // 初始化音频服务
    final audioHandler = audio_service.AudioService.init(
      builder: () => AudioHandler(),
      config: const audio_service.AudioServiceConfig(
        androidStopForegroundOnPause: false, // 设置为false以保持后台播放
        androidNotificationChannelId: 'com.example.listen2.channel.audio',
        androidNotificationChannelName: 'Listen2 Audio Service',
        androidNotificationOngoing: false, // 设置为false以避免与androidStopForegroundOnPause冲突
        androidShowNotificationBadge: true,
        fastForwardInterval: Duration(seconds: 10),
        rewindInterval: Duration(seconds: 10),
        notificationColor: Color(0xFF2196F3),
        androidNotificationIcon: 'mipmap/ic_launcher' // 确保通知图标正确
        // androidEnableQueue 参数在当前版本不支持，已移除
      ),
    );

    return audioHandler;
  } catch (e) {
    debugPrint('初始化音频服务时出错: $e');
    rethrow;
  }
}
