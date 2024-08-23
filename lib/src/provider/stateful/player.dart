import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/stateful/track.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'player.g.dart';

class PlayerState {
  ap.PlayerState state;
  Duration now;
  Duration length;

  PlayerState(
      {required this.state,
      this.now = Duration.zero,
      this.length = Duration.zero});

  PlayerState copyWith(
      {ap.PlayerState? state, Duration? length, Duration? now}) {
    return PlayerState(
        state: state ?? this.state,
        length: length ?? this.length,
        now: now ?? this.now);
  }
}

@riverpod
class PlayerStateNotifier extends _$PlayerStateNotifier {
  late ap.AudioPlayer _player;
  late StreamSubscription _playerStateChangeSubscription;
  late StreamSubscription _durationChangeSubscription;
  late StreamSubscription _positionChangeSubscription;
  late ProviderSubscription _currentSubscription;

  @override
  PlayerState build() {
    _player = ap.AudioPlayer();
    _playerStateChangeSubscription = _player.onPlayerStateChanged.listen((e) {
      print('listened_state$e');
      state = state.copyWith(state: e);
    });

    _durationChangeSubscription = _player.onDurationChanged.listen((e) async {
      state = state.copyWith(length: e);
    });

    _positionChangeSubscription = _player.onPositionChanged.listen((e) {
      state = state.copyWith(now: e);
    });

    _currentSubscription =
        ref.listen(currentTrackProvider, (previousTrack, track) async {
      if (track == null) return;
      if (track == previousTrack) return;
      debugPrint('play_track${track.title}');

      await _player.release();

      var bytes = await ref.read(trackBytesProvider(track).future);
      await _player.play(ap.BytesSource(bytes));
    });

    ref.onDispose(() {
      debugPrint('info: call player disposal');
      _positionChangeSubscription.cancel();
      _durationChangeSubscription.cancel();
      _playerStateChangeSubscription.cancel();
      _currentSubscription.close();
      _player.release();
      _player.dispose();
    });

    return PlayerState(state: ap.PlayerState.stopped);
  }

  void pause() async {
    _player.pause();
  }

  void resume() async {
    if (_player.state == ap.PlayerState.completed) return;
    _player.resume();
  }

  Future seek(Duration position) async {
    print(position);
    await _player.seek(position);
  }
}
