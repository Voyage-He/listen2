import 'package:audioplayers/audioplayers.dart' as ad;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../track/Track.data.dart';

final player = ad.AudioPlayer();

final playerStateProvider = StateNotifierProvider<PlayerStateNotifier, PlayerState>((ref) => PlayerStateNotifier());

// [Player] is used because [Playerstate] identifier was used in audioplayer 
class PlayerState {
  ad.PlayerState state;
  Track? currentTrack;
  ad.Source? source;

  PlayerState({
    required this.state,
    this.currentTrack,
    this.source,
  });

  PlayerState copyWith({
    ad.PlayerState? state,
    Track? currentTrack,
    ad.Source? source,
  }) {
    return PlayerState(
      state: state ?? this.state,
      currentTrack: currentTrack ?? this.currentTrack,
      source: source ?? this.source,
    );
  }
}

class PlayerStateNotifier extends StateNotifier<PlayerState> {

  PlayerStateNotifier() :
    super(PlayerState(state: player.state)) {
    
    player.onPlayerStateChanged.listen((e) {
      print('listened_state$e');
      state = state.copyWith(state: e);
    });
  }

  playTrack(Track track) async {
    print('play_track${track.title}');
    if (track == state.currentTrack) return;
    await player.release();

    state = state.copyWith(currentTrack: track);

    var byteSource = ad.BytesSource(await trackRpstr.getBytes(track));
    
    await player.play(byteSource);
  }
}