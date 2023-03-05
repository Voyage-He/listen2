import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Colors;

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