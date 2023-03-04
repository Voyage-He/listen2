import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart' show Colors, Theme;

import 'package:listen2/src/bloc/player.cubit.dart';

import 'package:listen2/src/repo/track.repo.dart';

import 'package:listen2/src/widget/progress_bar.dart';

class Player extends StatelessWidget {
  const Player({super.key});

  @override
  Widget build(BuildContext context) {
    var blurImage = ClipRect(
      child: Stack(
        children: [
          BlocSelector<PlayerCubit, PlayerState, Track?>(
            selector: (state) => state.currentTrack,
            builder: (context, track) {
              return FutureBuilder(
                  future: TrackRepo().getCover(track!),
                  builder: ((context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return Image.memory(
                        fit: BoxFit.cover,
                        height: double.infinity,
                        snapshot.data!,
                        errorBuilder: (context, _, __) => Container(width: 50, height: 50, color: Colors.grey,),
                      );
                    }
                    else {
                      return Container(width: 50, height: 50, color: Colors.grey,);
                    }
                  })
                );
            },
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ] 
      ),
    );
    
    return Stack(
      children: [
        blurImage,
        Align(
          alignment: const Alignment(0, -0.5),
          child: BlocSelector<PlayerCubit, PlayerState, Track?>(
            selector: (state) => state.currentTrack,
            builder: (context, track) {
              return FutureBuilder(
                  future: TrackRepo().getCover(track!),
                  builder: ((context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return Image.memory(
                        height: 250,
                        width: 250,
                        snapshot.data!,
                        errorBuilder: (context, _, __) => Container(width: 50, height: 50, color: Colors.grey,),
                      );
                    }
                    else {
                      return Container(width: 50, height: 50, color: Colors.grey,);
                    }
                  })
                );
            },
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
}
