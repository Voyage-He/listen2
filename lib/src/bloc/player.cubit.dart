import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ad;
import 'package:bloc/bloc.dart';

import '../repo/track.repo.dart';

class PlayerCubit extends Cubit<PlayerState> {
  final _player = ad.AudioPlayer();
  late StreamSubscription _playerStateChangeSubscription;
  late StreamSubscription _durationChangeSubscription;
  late StreamSubscription _positionChangeSubscription;

  PlayerCubit() : super(PlayerState(state: ad.PlayerState.stopped)) {
    _playerStateChangeSubscription = _player.onPlayerStateChanged.listen((e) {
      print('listened_state$e');
      emit(state.copyWith(state: e));
    });

    _durationChangeSubscription = _player.onDurationChanged.listen((e) async {
      emit(state.copyWith(length: e));
    });

    _positionChangeSubscription = _player.onPositionChanged.listen((e) {
      emit(state.copyWith(now: e));
    });
  }

  playTrack(Track track) async {
    print('play_track${track.title}');
    if (track == state.currentTrack) return;
    await _player.release();

    emit(state.copyWith(currentTrack: track));

    var byteSource = ad.BytesSource(await TrackRepo().getBytes(track));
    
    await _player.play(byteSource);
  }

  pause() async {
    _player.pause();
  }

  resume() async {
    if (_player.state == ad.PlayerState.completed) return;
    _player.resume();
  }

  seek(Duration position) async {
    print(position);
    await _player.seek(position);
  }

  @override
  Future close() async {
    _positionChangeSubscription.cancel();
    _durationChangeSubscription.cancel();
    _playerStateChangeSubscription.cancel();
    _player.dispose();
    super.close();
  }
}

class PlayerState {
  ad.PlayerState state;
  Duration now;
  Duration length;
  Track? currentTrack;

  PlayerState({
    required this.state,
    this.currentTrack,
    this.now = Duration.zero,
    this.length =Duration.zero
  });

  PlayerState copyWith({
    ad.PlayerState? state,
    Track? currentTrack,
    Duration? length,
    Duration? now
  }) {
    return PlayerState(
      state: state ?? this.state,
      currentTrack: currentTrack ?? this.currentTrack,
      length: length ?? this.length,
      now: now ?? this.now
    );
  }
}