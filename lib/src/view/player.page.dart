import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart' show Colors, Theme;

import 'package:listen2/src/bloc/player.cubit.dart';

import 'package:listen2/src/repo/track.repo.dart';

import './track_cover.widget.dart';
import 'package:listen2/src/widget/progress_bar.dart';

class Player extends StatelessWidget {
  const Player({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _blurImage(),
        Align(
          alignment: const Alignment(0, -0.5),
          child: BlocSelector<PlayerCubit, PlayerState, Track?>(
            selector: (state) => state.currentTrack,
            builder: (context, track) => track != null ? TrackCover(track, width: 250, height: 250) : Container(width: 50, height: 50, color: Colors.grey,),
          ),
        ),
        Align(
          alignment: const Alignment(0, 0.3),
          child: BlocSelector<PlayerCubit, PlayerState, List<Duration>>(
            selector: (state) => [state.now, state.length],
            builder: (context, state) {
              final now = state[0];
              final length = state[1];
              final nowMin = now.inMinutes;
              final nowSec = now.inSeconds - (60 * nowMin);
              final lengthMin = length.inMinutes;
              final lengthSec = length.inSeconds - (60 * lengthMin);

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$nowMin:$nowSec', style: Theme.of(context).textTheme.bodyLarge),
                  ProgressBar(now: now.inSeconds / length.inSeconds, onSeek: (seek) async {
                    final position = length * seek;
                    await context.read<PlayerCubit>().seek(position);
                  }),
                  Text('$lengthMin:$lengthSec', style: Theme.of(context).textTheme.bodyLarge),
                ],
              );
            },
          ),
        )
      ],
    );
  }

  Widget _blurImage() {
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: BlocSelector<PlayerCubit, PlayerState, Track?>(
          selector: (state) => state.currentTrack,
          builder: (context, track) => TrackCover(track!, height: double.infinity, fit: BoxFit.cover)
        ),
      ),
    );
  }

}
