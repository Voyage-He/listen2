import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/player.dart';

import 'package:listen2/src/provider/repo/track.dart';

class TrackCover extends ConsumerWidget {
  final Track track;
  final double? height;
  final double? width;
  final BoxFit? fit;

  const TrackCover(this.track, {this.width, this.height, this.fit, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = ref.watch(trackCoverProvider(track));
    return cover.maybeWhen(data: (data) {
      return Image.memory(
        data,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, _, __) => Container(
          width: 50,
          height: 50,
          color: Colors.grey,
        ),
      );
    }, orElse: () {
      return Container(
        width: 50,
        height: 50,
        color: Colors.grey,
      );
    });
  }
}

class CurrentTrackCover extends ConsumerWidget {
  final double? height;
  final double? width;
  final BoxFit? fit;

  const CurrentTrackCover({this.width, this.height, this.fit, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var track = ref.watch(playerStateNotifierProvider.select((it) => it.track));
    if (track != null) {
      return TrackCover(track, width: width, height: height, fit: fit);
    } else {
      return Container(
        width: 50,
        height: 50,
        color: Colors.grey,
      );
    }
  }
}
