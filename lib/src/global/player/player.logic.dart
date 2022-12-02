import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_api/music_api.dart';

import '../track/Track.data.dart';

// TODO
// CurrentTrackProvider, StatusProvider
// and put them into MultiProvier to manage player

final playerPrvd = StateNotifierProvider<Player, PlayerStatus>((ref) => Player() );

enum PlayerStatus{
  empty,
  playe,
  pause,
  stope
}

class Player extends StateNotifier<PlayerStatus> {
  final AudioPlayer player = AudioPlayer();

  Player() : super(PlayerStatus.empty){print('init===========================================================');}

  Future<void> playTrack(Track track) async {

    await player.stop();
    await player.release();
    await player.setSource(BytesSource(await trackRpstr.getBytes(track)));
    await player.resume();
    print("resume");
  }

  @override
  void dispose() {
    player.dispose();
    print('dispose=====================================================');
    super.dispose();
  }
}
