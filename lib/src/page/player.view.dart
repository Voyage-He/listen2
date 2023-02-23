import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart' show Colors;

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
          BlocBuilder<PlayerCubit, PlayerState>(
            buildWhen: (previous, current) => previous.currentTrack != current.currentTrack,
            builder: (context, playerState) {
              return FutureBuilder(
                  future: TrackRepo().getCover(playerState.currentTrack!),
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
          child: BlocBuilder<PlayerCubit, PlayerState>(
            buildWhen: (previous, current) => previous.currentTrack != current.currentTrack,
            builder: (context, playerState) {
              return FutureBuilder(
                  future: TrackRepo().getCover(playerState.currentTrack!),
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
          child: BlocBuilder<PlayerCubit, PlayerState>(
            builder: (context, state) {
              final nowMin = state.now.inMinutes;
              final nowSec = state.now.inSeconds - (60 * nowMin);
              final lengthMin = state.length.inMinutes;
              final lengthSec = state.length.inSeconds - (60 * lengthMin);

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${nowMin}:${nowSec}', style: TextStyle(fontSize: 15),),
                  ProgressBar(now: state.now.inSeconds / state.length.inSeconds, onSeek: (seek) async {
                    final position = state.length * seek;
                    await context.read<PlayerCubit>().seek(position);
                  }),
                  Text('${lengthMin}:${lengthSec}', style: TextStyle(fontSize: 15),),
                ],
              );
            },
          ),
        )
      ],
    );
  }
}
