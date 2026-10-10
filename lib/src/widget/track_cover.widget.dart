import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/player.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:listen2/src/widget/app_style.dart';

class CoverPlaceholder extends StatelessWidget {
  const CoverPlaceholder({super.key, this.width, this.height});
  final double? width;
  final double? height;
  @override
  Widget build(BuildContext context) => Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE5D8B6), Color(0xFFC3CAA9)])),
      child: const Center(
          child: Icon(Icons.music_note_rounded,
              color: AppStyle.accent, size: 28)));
}

class TrackCover extends ConsumerWidget {
  const TrackCover(this.track, {this.width, this.height, this.fit, super.key});
  final Track track;
  final double? height;
  final double? width;
  final BoxFit? fit;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(trackCoverProvider(track)).maybeWhen(
          data: (data) => Image.memory(data,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) =>
                  CoverPlaceholder(width: width, height: height)),
          orElse: () => CoverPlaceholder(width: width, height: height));
}

class CurrentTrackCover extends ConsumerWidget {
  const CurrentTrackCover({this.width, this.height, this.fit, super.key});
  final double? height;
  final double? width;
  final BoxFit? fit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track =
        ref.watch(playerStateNotifierProvider.select((it) => it.track));
    return track == null
        ? CoverPlaceholder(width: width, height: height)
        : TrackCover(track, width: width, height: height, fit: fit);
  }
}
