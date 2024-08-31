import 'dart:async';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/widgets.dart';
import 'package:listen2/src/provider/stateful/track.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:audio_service/audio_service.dart';

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
class AudioHandler extends BaseAudioHandler {
  final player = ap.AudioPlayer();

  AudioHandler() {
    // AudioHandler need playing state to run in background
    playbackState.add(PlaybackState(
      playing: false,
    ));
  }

  void dispose() {
    debugPrint('info: audiohandler disposal');
    player.dispose();
  }
}

@riverpod
class PlayerStateNotifier extends _$PlayerStateNotifier {
  late AudioHandler _audioHandler;
  late StreamSubscription _playerStateChangeSubscription;
  late StreamSubscription _durationChangeSubscription;
  late StreamSubscription _positionChangeSubscription;

  @override
  PlayerState build() {
    _audioHandler = ref.watch(audioHandlerProvider).requireValue;
    _playerStateChangeSubscription =
        _audioHandler.player.onPlayerStateChanged.listen((e) async {
      print('listened_state$e');
      state = state.copyWith(state: e);
    });

    _durationChangeSubscription =
        _audioHandler.player.onDurationChanged.listen((e) async {
      state = state.copyWith(length: e);
    });

    _positionChangeSubscription =
        _audioHandler.player.onPositionChanged.listen((e) async {
      state = state.copyWith(now: e);
    });

    ref.onDispose(() {
      debugPrint('info: call player disposal');
      _positionChangeSubscription.cancel();
      _durationChangeSubscription.cancel();
      _playerStateChangeSubscription.cancel();
      _audioHandler.dispose();
    });

    return PlayerState();
  }

  Future<void> playTrack(Track track) async {
    debugPrint('play_track${track.title}');

    await _audioHandler.player.release();

    var bytes = await ref.read(trackBytesProvider(track).future);
    await _audioHandler.player.play(ap.BytesSource(bytes));
    _audioHandler.playbackState
        .add(_audioHandler.playbackState.value.copyWith(playing: true));

    state = state.copyWith(track: track);
  }

  Future<void> pause() async {
    await _audioHandler.player.pause();
    _audioHandler.playbackState
        .add(_audioHandler.playbackState.value.copyWith(playing: false));
  }

  Future<void> resume() async {
    if (state == ap.PlayerState.completed) return;
    await _audioHandler.player.resume();
    _audioHandler.playbackState
        .add(_audioHandler.playbackState.value.copyWith(playing: true));
  }

  Future<void> seek(Duration position) async {
    print(position);
    await _audioHandler.player.seek(position);
  }
}

@riverpod
Future<AudioHandler> audioHandler(AudioHandlerRef ref) async {
  return await AudioService.init(
    builder: () => AudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mycompany.myapp.channel.audio',
      androidNotificationChannelName: 'Music playback',
    ),
  );
}
