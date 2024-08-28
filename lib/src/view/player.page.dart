import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/stateful/player.dart';

import './track_cover.widget.dart';
import 'package:listen2/src/widget/progress_bar.dart';

class Player extends StatelessWidget {
  const Player({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _blurImage(),
        const Align(
            alignment: Alignment(0, -0.5),
            child: CurrentTrackCover(width: 250, height: 250)),
        Align(
          alignment: const Alignment(0, 0.3),
          child: _PlayerProgress(),
        )
      ],
    );
  }

  Widget _blurImage() {
    return ClipRect(
      child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: const CurrentTrackCover(
              height: double.infinity, fit: BoxFit.cover)),
    );
  }

  Widget _PlayerProgress() {
    return Consumer(
      builder: (context, ref, child) {
        var playerState = ref.watch(playerStateNotifierProvider);
        final now = playerState.now;
        // final length = playerState.length;
        final length = const Duration(minutes: 3);
        final nowMin = now.inMinutes;
        final nowSec = now.inSeconds - (60 * nowMin);
        final lengthMin = length.inMinutes;
        final lengthSec = length.inSeconds - (60 * lengthMin);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$nowMin:$nowSec',
                style: Theme.of(context).textTheme.bodyLarge),
            ProgressBar(
                now: now.inSeconds / length.inSeconds,
                onSeek: (seek) async {
                  final position = length * seek;
                  await ref
                      .read(playerStateNotifierProvider.notifier)
                      .seek(position);
                }),
            Text('$lengthMin:$lengthSec',
                style: Theme.of(context).textTheme.bodyLarge),
          ],
        );
      },
    );
  }
}
