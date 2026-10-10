import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/background_settings.dart';
import 'package:listen2/src/provider/global/player.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:listen2/src/widget/app_style.dart';

class PlayerBackground extends ConsumerWidget {
  const PlayerBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track =
        ref.watch(playerStateNotifierProvider.select((state) => state.track));
    if (track == null) return const SizedBox.expand();
    final cover = ref.watch(trackCoverProvider(track)).valueOrNull;
    if (cover == null) return const SizedBox.expand();
    final settings = ref.watch(backgroundSettingsProvider);
    return ClipRect(
        child: Stack(fit: StackFit.expand, children: [
      ImageFiltered(
          enabled: settings.blur > 0,
          imageFilter:
              ImageFilter.blur(sigmaX: settings.blur, sigmaY: settings.blur),
          child: Transform.scale(
              scale: 1.15,
              child: Image.memory(cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.expand()))),
      DecoratedBox(
          key: const ValueKey('background-gradient'),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                AppStyle.background.withOpacity(settings.gradient * .58),
                AppStyle.background.withOpacity(settings.gradient * .75),
                AppStyle.background.withOpacity(settings.gradient),
              ]))),
    ]));
  }
}
