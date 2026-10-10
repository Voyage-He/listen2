import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/player.dart';
import 'package:listen2/src/view/page/player/player.page.dart';
import 'package:listen2/src/widget/track_cover.widget.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';

class BottomPlayer extends ConsumerWidget {
  const BottomPlayer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(audioHandlerProvider).valueOrNull == null) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(playerStateNotifierProvider);
    final track = state.track;
    final playing = state.state == ap.PlayerState.playing;
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Material(
            color: vinylInk,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const Player())),
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(children: [
                    SizedBox(
                        width: 48,
                        height: 48,
                        child: VinylRecord(
                            playing: playing,
                            position: state.now,
                            cover: const CurrentTrackCover(
                                width: 48, height: 48, fit: BoxFit.cover))),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(track?.title ?? '打开你的唱机',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: vinylCream,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 5),
                          Text(track?.singer ?? '选一张唱片，让音乐转起来',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFFABB19E), fontSize: 11)),
                        ])),
                    IconButton(
                        tooltip: '打开唱机',
                        icon: const Icon(Icons.open_in_full_rounded,
                            color: vinylGold, size: 20),
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const Player()))),
                  ])),
            )));
  }
}
