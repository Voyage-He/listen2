import 'package:audioplayers/audioplayers.dart' as ad;
import 'package:bloc/bloc.dart';

import '../repo/track.repo.dart';

class PlayerCubit extends Cubit<PlayerState> {
  final _player = ad.AudioPlayer();

  PlayerCubit() : super(PlayerState(state: ad.PlayerState.stopped)) {
    _player.onPlayerStateChanged.listen((e) {
      print('listened_state$e');
      emit(state.copyWith(state: e));
    });

    _player.onDurationChanged.listen((e) async {
      emit(state.copyWith(length: e));
    });

    _player.onPositionChanged.listen((e) {
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
    _player.resume();
  }

  seek(Duration position) async {
    print(position);
    await _player.seek(position);
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