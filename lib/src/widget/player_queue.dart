import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/current_playlist.dart';
import 'package:listen2/src/provider/global/player.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';

class PlayerQueue extends ConsumerStatefulWidget {
  const PlayerQueue({
    super.key,
    required this.onChoosePlaylist,
    required this.onPlay,
  });

  final VoidCallback onChoosePlaylist;
  final Future<void> Function(String id, List<String> ids) onPlay;

  @override
  ConsumerState<PlayerQueue> createState() => _PlayerQueueState();
}

class _PlayerQueueState extends ConsumerState<PlayerQueue> {
  final _scroll = ScrollController();
  Timer? _focusTimer;
  int _focusGeneration = 0;
  int? _focusedIndex;
  String? _focusedId;

  double get _itemExtent {
    final scaler = MediaQuery.textScalerOf(context);
    return math.max(72, scaler.scale(16) * 1.4 + scaler.scale(14) * 1.4 + 24);
  }

  int _currentIndex(CurrentPlaylistState queue, String? id) {
    if (id == null) return -1;
    if (queue.index >= 0 &&
        queue.index < queue.playlist.length &&
        queue.playlist[queue.index] == id) {
      return queue.index;
    }
    return queue.playlist.indexOf(id);
  }

  Future<void> _locateCurrent() async {
    if (!mounted || !_scroll.hasClients) return;
    final id = ref.read(playerStateNotifierProvider).track?.bvid;
    final queue = ref.read(currentPlaylistNotifierProvider);
    final index = _currentIndex(queue, id);
    if (index < 0) return;
    final generation = ++_focusGeneration;
    final position = _scroll.position;
    final target =
        (index * _itemExtent - (position.viewportDimension - _itemExtent) / 2)
            .clamp(0.0, position.maxScrollExtent)
            .toDouble();
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _scroll.animateTo(target,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic);
    } else {
      _scroll.jumpTo(target);
    }
    if (!mounted ||
        generation != _focusGeneration ||
        ref.read(playerStateNotifierProvider).track?.bvid != id ||
        _currentIndex(ref.read(currentPlaylistNotifierProvider), id) != index) {
      return;
    }
    _focusTimer?.cancel();
    setState(() {
      _focusedIndex = index;
      _focusedId = id;
    });
    _focusTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _focusedIndex = null;
        _focusedId = null;
      });
    });
  }

  @override
  void dispose() {
    _focusGeneration++;
    _focusTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(
        playerStateNotifierProvider.select((state) => state.track?.bvid));
    final queue = currentId == null
        ? const CurrentPlaylistState(index: 0, playlist: [])
        : ref.watch(currentPlaylistNotifierProvider);
    final ids = currentId == null ? <String>[] : queue.playlist;
    final currentIndex = _currentIndex(queue, currentId);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 16, 12),
        child: Row(children: [
          const Expanded(
            child: Text('播放列表',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: vinylInk,
                    fontSize: 22,
                    fontWeight: FontWeight.w600)),
          ),
          IconButton(
            key: const ValueKey('queue-locate-current'),
            tooltip: '定位当前歌曲',
            onPressed:
                currentIndex < 0 ? null : () => unawaited(_locateCurrent()),
            icon: const Icon(Icons.my_location_rounded, color: vinylOlive),
          ),
          TextButton.icon(
              onPressed: widget.onChoosePlaylist,
              icon: const Icon(Icons.library_music_outlined, size: 18),
              label: const Text('选歌单')),
        ]),
      ),
      Expanded(
          child: ids.isEmpty
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('从歌单选择音乐，唱片会按顺序放入这里',
                          textAlign: TextAlign.center)))
              : ScrollConfiguration(
                  behavior:
                      ScrollConfiguration.of(context).copyWith(dragDevices: {
                    ...ScrollConfiguration.of(context).dragDevices,
                    PointerDeviceKind.mouse,
                  }),
                  child: ListView.builder(
                    controller: _scroll,
                    itemExtent: _itemExtent,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: ids.length,
                    itemBuilder: (context, index) {
                      final id = ids[index];
                      final item = ref.watch(trackProvider(id));
                      final current = index == currentIndex;
                      final focused =
                          current && index == _focusedIndex && id == _focusedId;
                      return AnimatedContainer(
                        key: ValueKey('queue-focus-$index'),
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: focused
                              ? vinylGold.withOpacity(.38)
                              : current
                                  ? vinylOlive.withOpacity(.08)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: focused ? vinylGold : Colors.transparent),
                        ),
                        child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              key: ValueKey('queue-track-$index'),
                              selected: current,
                              selectedColor: vinylInk,
                              minVerticalPadding: 8,
                              leading: Icon(
                                  current
                                      ? Icons.album_rounded
                                      : Icons.album_outlined,
                                  color: current ? vinylGold : vinylOlive),
                              title: Text(
                                  item.when(
                                      data: (track) => track.title,
                                      loading: () => '正在取出唱片…',
                                      error: (_, __) => '唱片加载失败'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 16,
                                      height: 1.4,
                                      fontWeight: current
                                          ? FontWeight.w600
                                          : FontWeight.normal)),
                              subtitle: item.maybeWhen(
                                  data: (track) => Text(track.singer,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 14, height: 1.4)),
                                  orElse: () => null),
                              trailing: item.hasError
                                  ? IconButton(
                                      tooltip: '重试',
                                      icon: const Icon(Icons.refresh),
                                      onPressed: () =>
                                          ref.invalidate(trackProvider(id)))
                                  : null,
                              onTap: item.maybeWhen(
                                  data: (_) => () {
                                        Navigator.of(context).pop();
                                        unawaited(
                                            widget.onPlay(id, List.of(ids)));
                                      },
                                  orElse: () => null),
                            )),
                      );
                    },
                  ),
                )),
    ]);
  }
}
