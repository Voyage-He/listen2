import 'dart:async';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/widgets.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

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

@Riverpod(keepAlive: true)
class PlayerStateNotifier extends _$PlayerStateNotifier {
  late AudioHandler _audioHandler;
  late StreamSubscription _playerStateChangeSubscription;
  late StreamSubscription _durationChangeSubscription;
  late StreamSubscription _positionChangeSubscription;
  late StreamSubscription _interruptionEventSubscription;
  bool _isInterrupt = false;

  @override
  PlayerState build() {
    _audioHandler = ref.watch(audioHandlerProvider).requireValue;

    //
    const audioFocusNone = ap.AudioContext(
        android: ap.AudioContextAndroid(audioFocus: ap.AndroidAudioFocus.none));
    _audioHandler.player.setAudioContext(audioFocusNone);

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

    _durationChangeSubscription =
        _audioHandler.player.onDurationChanged.listen((e) async {
      state = state.copyWith(length: e);
    });

    _positionChangeSubscription =
        _audioHandler.player.onPositionChanged.listen((e) async {
      state = state.copyWith(now: e);
    });

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

    ref.onDispose(() {
      debugPrint('info: call player disposal');
      _positionChangeSubscription.cancel();
      _durationChangeSubscription.cancel();
      _playerStateChangeSubscription.cancel();
      _interruptionEventSubscription.cancel();
      _audioHandler.dispose();
    });

    return PlayerState();
  }

  Future<void> playTrack(Track track) async {
    debugPrint('play_track${track.title}');

    await _audioHandler.player.release();

    final session = await AudioSession.instance;
    if (!(await session.setActive(true))) return;

    var bytes = await ref.read(trackBytesProvider(track).future);
    await _audioHandler.player.play(ap.BytesSource(bytes));

    state = state.copyWith(track: track);
  }

  Future<void> playTrackById(String trackId) async {
    if (trackId.isEmpty) {
      state = PlayerState();
      return;
    }
    final track = await ref.read(trackProvider(trackId).future);
    await playTrack(track);
  }

  Future<void> pause() async {
    await _audioHandler.player.pause();
  }

  Future<void> resume() async {
    if (state == ap.PlayerState.completed) return;

    final session = await AudioSession.instance;
    if (!(await session.setActive(true))) return;

    await _audioHandler.player.resume();
  }

  Future<void> seek(Duration position) async {
    print(position);
    await _audioHandler.player.seek(position);
  }
}

@Riverpod(keepAlive: true)
Future<AudioHandler> audioHandler(AudioHandlerRef ref) async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  final audioHandler = AudioService.init(
    builder: () => AudioHandler(),
    config: const AudioServiceConfig(
      androidStopForegroundOnPause: false,
    ),
  );

  return audioHandler;
}
