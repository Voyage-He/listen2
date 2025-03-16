import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Colors, Icons, Theme;
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/player.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:listen2/src/ref_extensions.dart';

import 'package:listen2/src/view/page/player/player.page.dart';

import 'package:listen2/src/widget/track_cover.widget.dart';

class BottomPlayer extends ConsumerWidget {
  const BottomPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var track = ref.watch(playerStateNotifierProvider.select((it) => it.track));
    return GestureDetector(
      onTap: () => _navigate2PlayerPage(context, track),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Color.fromARGB(80, 0, 0, 0),
              offset: Offset(0, 0),
              blurRadius: 10.0,
              spreadRadius: 0.0)
        ]),
        child: Row(
          children: [
            _cover(),
            _title(track),
            _controlButton(ref),
            const Icon(
              Icons.list,
              size: 40,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover() {
    return const CurrentTrackCover(width: 50, height: 50);
  }

  Widget _title(Track? track) {
    return Expanded(
        child: Text(track?.title ?? '',
            style: const TextStyle(
                fontSize: 20, overflow: TextOverflow.ellipsis)));
  }

  Widget _controlButton(WidgetRef ref) {
    var playerState = ref.playerState;
    final isPlaying = playerState.state == ap.PlayerState.playing;
    // print('controlbutton$isPlaying');
    return GestureDetector(
        onTap: () {
          final player = ref.read(playerStateNotifierProvider.notifier);
          if (isPlaying) {
            player.pause();
          } else {
            player.resume();
          }
        },
        child: Icon(
          isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
          size: 35,
        ));
  }

  void _navigate2PlayerPage(BuildContext context, Track? track) {
    if (track == null) return;
    Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
      pageBuilder: (context, _, __) => const Player(),
      transitionDuration: const Duration(milliseconds: 100),
      reverseTransitionDuration: const Duration(milliseconds: 100),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(animation),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
    ));
  }
}
