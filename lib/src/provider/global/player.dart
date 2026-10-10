import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

/// Connects the player to iOS Now Playing and Android media controls.
class AudioHandler extends BaseAudioHandler {
  final player = ap.AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _resumeAfterInterruption = false;
  bool _ducked = false;

  Future<void> initialize() async {
    await player.setAudioContext(const ap.AudioContext(
      android: ap.AudioContextAndroid(audioFocus: ap.AndroidAudioFocus.none),
      iOS: ap.AudioContextIOS(category: ap.AVAudioSessionCategory.playback),
    ));
    // Configure after the player so plugin defaults cannot replace music mode.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _subscriptions.add(player.onPlayerStateChanged.listen((state) {
      _publishState(state);
    }));
    _subscriptions.add(player.onPositionChanged.listen((position) {
      playbackState.add(playbackState.value.copyWith(updatePosition: position));
    }));
    _subscriptions.add(player.onDurationChanged.listen((duration) {
      final item = mediaItem.value;
      if (item != null) mediaItem.add(item.copyWith(duration: duration));
    }));
    _subscriptions.add(session.becomingNoisyEventStream.listen((_) => pause()));
    _subscriptions.add(session.interruptionEventStream.listen((event) async {
      if (event.type == AudioInterruptionType.duck) {
        if (event.begin && player.state == ap.PlayerState.playing) {
          _ducked = true;
          await player.setVolume(0.2);
        } else if (!event.begin && _ducked) {
          _ducked = false;
          await player.setVolume(1);
        }
        return;
      }
      if (event.begin) {
        final wasPlaying = player.state == ap.PlayerState.playing;
        await pause();
        _resumeAfterInterruption = wasPlaying;
      } else {
        final shouldResume = _resumeAfterInterruption &&
            event.type == AudioInterruptionType.pause;
        _resumeAfterInterruption = false;
        if (shouldResume) await play();
      }
    }));
    _publishState(player.state);
  }

  void _publishState(ap.PlayerState state) {
    final playing = state == ap.PlayerState.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0],
      playing: playing,
      processingState: state == ap.PlayerState.completed
          ? AudioProcessingState.completed
          : state == ap.PlayerState.stopped || state == ap.PlayerState.disposed
              ? AudioProcessingState.idle
              : AudioProcessingState.ready,
    ));
  }

  @override
  Future<void> play() async {
    if (player.source == null || player.state == ap.PlayerState.completed) {
      return;
    }
    final session = await AudioSession.instance;
    if (await session.setActive(true)) await player.resume();
  }

  /// Mount a record without spinning it when the needle is raised.
  Future<void> load(ap.Source source, {bool autoplay = true}) async {
    await player.setSource(source);
    if (autoplay) {
      await play();
    } else {
      await pause();
    }
  }

  @override
  Future<void> pause() async {
    _resumeAfterInterruption = false;
    await player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
  }

  @override
  Future<void> stop() async {
    _resumeAfterInterruption = false;
    await player.stop();
    final session = await AudioSession.instance;
    await session.setActive(false);
    await super.stop();
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await player.dispose();
  }
}

@Riverpod(keepAlive: true)
class PlayerStateNotifier extends _$PlayerStateNotifier {
  late AudioHandler _audioHandler;
  int _playRequest = 0;

  @override
  PlayerState build() {
    _audioHandler = ref.watch(audioHandlerProvider).requireValue;
    final subscriptions = <StreamSubscription<dynamic>>[
      _audioHandler.player.onPlayerStateChanged.listen((value) {
        state = state.copyWith(state: value);
      }),
      _audioHandler.player.onDurationChanged.listen((value) {
        state = state.copyWith(length: value);
      }),
      _audioHandler.player.onPositionChanged.listen((value) {
        state = state.copyWith(now: value);
      }),
    ];
    ref.onDispose(() {
      _playRequest++;
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });
    return PlayerState();
  }

  Future<void> playTrack(Track track, {bool autoplay = true}) async {
    final request = ++_playRequest;
    final bytes = await ref.read(trackBytesProvider(track).future);
    if (request != _playRequest) return;

    ap.Source source = ap.BytesSource(bytes);
    if (Platform.isIOS) {
      // AVPlayer needs a file with the actual container extension (Bilibili AAC).
      final directory = await getTemporaryDirectory();
      final name = base64Url.encode(utf8.encode(track.bvid));
      final file = File(path.join(directory.path, 'listen2-$name.m4a'));
      await file.writeAsBytes(bytes, flush: true);
      source = ap.DeviceFileSource(file.path);
    }
    if (request != _playRequest) return;
    await _audioHandler.player.release();
    if (request != _playRequest) return;

    state = PlayerState(track: track);
    _audioHandler.mediaItem.add(MediaItem(
      id: track.bvid,
      title: track.title,
      artist: track.singer,
      artUri: Uri.tryParse(track.pictureUrl),
    ));
    _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
      updatePosition: Duration.zero,
      processingState: AudioProcessingState.loading,
    ));
    try {
      await _audioHandler.load(source, autoplay: autoplay);
    } catch (_) {
      await _audioHandler.stop();
      rethrow;
    }
  }

  Future<void> playTrackById(String trackId, {bool autoplay = true}) async {
    if (trackId.isEmpty) {
      _playRequest++;
      await _audioHandler.stop();
      _audioHandler.mediaItem.add(null);
      state = PlayerState();
      return;
    }
    final track = await ref.read(trackProvider(trackId).future);
    await playTrack(track, autoplay: autoplay);
  }

  Future<void> pause() => _audioHandler.pause();
  Future<void> resume() => _audioHandler.play();
  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
    state = state.copyWith(now: position);
  }
}

@Riverpod(keepAlive: true)
Future<AudioHandler> audioHandler(AudioHandlerRef ref) async {
  final handler = await AudioService.init(
    builder: () => AudioHandler(),
    config: const AudioServiceConfig(androidStopForegroundOnPause: false),
  );
  await handler.initialize();
  ref.onDispose(() => handler.dispose());
  return handler;
}
