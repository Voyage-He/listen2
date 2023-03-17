import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart' show Colors;

import 'package:listen2/src/bloc/player.cubit.dart';

import 'package:listen2/src/repo/track.repo.dart';

class TrackCover extends StatelessWidget {
  final Track track;
  final double? height;
  final double? width;
  final BoxFit? fit;

  const TrackCover(this.track, {
    this.width,
    this.height,
    this.fit,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: TrackRepo().getCover(track),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, _, __) => Container(width: 50, height: 50, color: Colors.grey,),
          );
        }
        else {
          return Container(width: 50, height: 50, color: Colors.grey,);
        }
      }
    );
  }
}

class CurrentTrackCover extends StatelessWidget {
  final double? height;
  final double? width;
  final BoxFit? fit;

  const CurrentTrackCover({
    this.width,
    this.height,
    this.fit,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlayerCubit, PlayerState, Track?>(
      selector: (state) => state.currentTrack,
      builder: (context, track) {
        if (track != null) {
          return TrackCover(track, width: width, height: height, fit: fit);
        }
        else {
          return Container(width: 50, height: 50, color: Colors.grey,);
        }
      },
    );
  }
}