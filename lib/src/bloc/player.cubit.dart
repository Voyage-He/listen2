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
}

class PlayerState {
  ad.PlayerState state;
  Track? currentTrack;

  PlayerState({
    required this.state,
    this.currentTrack,
  });

  PlayerState copyWith({
    ad.PlayerState? state,
    Track? currentTrack,
    ad.Source? source,
  }) {
    return PlayerState(
      state: state ?? this.state,
      currentTrack: currentTrack ?? this.currentTrack);
  }
}