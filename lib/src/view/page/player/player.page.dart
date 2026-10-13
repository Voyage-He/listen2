import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/player.dart';
import 'package:listen2/src/provider/global/current_playlist.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:listen2/src/view/page/search/search.page.dart';
import 'package:listen2/src/widget/track_cover.widget.dart';
import 'package:listen2/src/widget/player_background.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';
import 'package:listen2/src/widget/playlist_picker.dart';
import 'package:listen2/src/widget/player_tutorial.dart';
import 'package:listen2/src/widget/record_shelf.dart';
import 'package:listen2/src/view/page/playlist/playlist.dart';
import 'package:listen2/src/view/page/option/option.page.dart';

class Player extends ConsumerStatefulWidget {
  const Player({super.key, this.isHome = false});
  final bool isHome;
  @override
  ConsumerState<Player> createState() => _PlayerState();
}

class _PlayerState extends ConsumerState<Player> {
  bool _busy = false;
  Duration? _scrubbing;
  String? _feedback;
  int? _unavailableDirection;
  Timer? _edgeFeedbackTimer;
  double _pageSwipeDistance = 0;

  Future<void> _showInstructions() async {
    final startTutorial = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: vinylCream,
      showDragHandle: true,
      isScrollControlled: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      builder: (context) => PlayerInstructions(
          onStartTutorial: () => Navigator.of(context).pop(true)),
    );
    if (!mounted || startTutorial != true) return;
    await showDialog<void>(
      context: context,
      useSafeArea: false,
      barrierDismissible: false,
      builder: (_) => PlayerTutorial(isHome: widget.isHome),
    );
  }

  void _openSidePage(int direction) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Navigator.of(context).push(PageRouteBuilder<void>(
      transitionDuration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 360),
      reverseTransitionDuration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) =>
          direction > 0 ? const Option() : const Search(),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
                  begin: Offset(direction > 0 ? -1 : 1, 0), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic)),
          child: child),
    ));
  }

  @override
  void dispose() {
    _edgeFeedbackTimer?.cancel();
    super.dispose();
  }

  void _showUnavailable(int direction) {
    _edgeFeedbackTimer?.cancel();
    setState(() {
      _unavailableDirection = direction;
      _feedback = null;
    });
    _edgeFeedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _unavailableDirection = null);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _edgeFeedbackTimer?.cancel();
    setState(() {
      _unavailableDirection = null;
      _busy = true;
      _feedback = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _feedback = '暂时无法播放，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _moveArm(bool lowered) async {
    final state = ref.read(playerStateNotifierProvider);
    if (state.track == null) {
      setState(() => _feedback = '尚未选择歌曲');
      return;
    }
    if (lowered == (state.state == ap.PlayerState.playing)) return;
    await _run(() async {
      final player = ref.read(playerStateNotifierProvider.notifier);
      if (!lowered) {
        await player.pause();
      } else if (state.state == ap.PlayerState.completed) {
        await player.playTrack(state.track!);
      } else {
        await player.resume();
      }
    });
  }

  Future<void> _skip(int direction) async {
    final track = ref.read(playerStateNotifierProvider).track;
    if (track == null) return;
    final playlist = ref.read(currentPlaylistNotifierProvider).playlist;
    final index = playlist.indexOf(track.bvid);
    final next = index + direction;
    if (index < 0 || next < 0 || next >= playlist.length) {
      _showUnavailable(direction);
      return;
    }
    await _run(() async {
      await ref.read(currentPlaylistNotifierProvider.notifier).skip(direction);
    });
  }

  Future<void> _showPlaylists() async {
    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: vinylCream,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SizedBox(
          height: MediaQuery.of(context).size.height * .65,
          child: const PlaylistPicker()),
    );
    if (!mounted || name == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            PlaylistPage(playlistName: name, returnToPlayerOnPlay: true)));
  }

  void _showQueue() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: vinylCream,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SizedBox(
          height: MediaQuery.of(context).size.height * .65,
          child: Consumer(builder: (context, ref, _) {
            final track = ref.watch(
                playerStateNotifierProvider.select((state) => state.track));
            final ids = track == null
                ? <String>[]
                : ref.watch(currentPlaylistNotifierProvider).playlist;
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 16, 12),
                      child: Row(children: [
                        const Expanded(
                            child: Text('唱片架',
                                style: TextStyle(
                                    color: vinylInk,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600))),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showPlaylists();
                          },
                          icon: const Icon(Icons.library_music_outlined,
                              size: 18),
                          label: const Text('选歌单'),
                        ),
                      ])),
                  Expanded(
                      child: ids.isEmpty
                          ? const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('从歌单选择音乐，唱片会按顺序放入这里',
                                      textAlign: TextAlign.center)))
                          : ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context)
                                  .copyWith(dragDevices: {
                                ...ScrollConfiguration.of(context).dragDevices,
                                PointerDeviceKind.mouse,
                              }),
                              child: ListView.builder(
                                  itemCount: ids.length,
                                  itemBuilder: (context, index) => ref
                                      .watch(trackProvider(ids[index]))
                                      .when(
                                        data: (item) => ListTile(
                                            leading: Icon(
                                                ids[index] == track?.bvid
                                                    ? Icons.album_rounded
                                                    : Icons.album_outlined,
                                                color: vinylOlive),
                                            title: Text(item.title,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            subtitle: Text(item.singer,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _run(() => ref
                                                  .read(
                                                      currentPlaylistNotifierProvider
                                                          .notifier)
                                                  .play(ids[index], ids));
                                            }),
                                        loading: () => const ListTile(
                                            title: Text('正在取出唱片…')),
                                        error: (_, __) => ListTile(
                                            title: const Text('唱片加载失败'),
                                            trailing: IconButton(
                                                tooltip: '重试',
                                                icon: const Icon(Icons.refresh),
                                                onPressed: () => ref.invalidate(
                                                    trackProvider(
                                                        ids[index])))),
                                      )))),
                ]);
          })),
    );
  }

  Future<void> _showSavePlaylists() async {
    final track = ref.read(playerStateNotifierProvider).track;
    if (track == null) return;
    setState(() => _feedback = null);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: vinylCream,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: PlaylistPicker(trackId: track.bvid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerStateNotifierProvider);
    final track = state.track;
    final singer = track?.singer.trim() ?? '';
    final playing = state.state == ap.PlayerState.playing;
    final textScaler = MediaQuery.textScalerOf(context);
    final queue = track == null
        ? <String>[]
        : ref.watch(currentPlaylistNotifierProvider).playlist;
    final index = track == null ? -1 : queue.indexOf(track.bvid);
    VinylTrackPreview? previewAt(int target) {
      if (index < 0 || target < 0 || target >= queue.length) return null;
      return ref.watch(trackProvider(queue[target])).maybeWhen(
            data: (item) => VinylTrackPreview(
              title: item.title,
              cover: TrackCover(item, fit: BoxFit.cover),
            ),
            orElse: () => null,
          );
    }

    final previous = previewAt(index - 1);
    final next = previewAt(index + 1);
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart:
            widget.isHome ? (_) => _pageSwipeDistance = 0 : null,
        onHorizontalDragUpdate: widget.isHome
            ? (details) => _pageSwipeDistance += details.delta.dx
            : null,
        onHorizontalDragEnd: widget.isHome
            ? (_) {
                if (_pageSwipeDistance.abs() >= 72) {
                  _openSidePage(_pageSwipeDistance > 0 ? 1 : -1);
                }
                _pageSwipeDistance = 0;
              }
            : null,
        onHorizontalDragCancel:
            widget.isHome ? () => _pageSwipeDistance = 0 : null,
        child: _PlayerSurface(
            color: vinylCream,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(children: [
                    if (widget.isHome)
                      const SizedBox(width: 48, height: 48)
                    else
                      IconButton(
                          tooltip: '返回',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: vinylInk)),
                    const Expanded(
                        child: Column(children: [
                      Text('LISTEN 2',
                          style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 3,
                              color: vinylInk,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('THE RECORD ROOM',
                          style: TextStyle(
                              fontSize: 8,
                              letterSpacing: 2,
                              color: vinylOlive)),
                    ])),
                    IconButton(
                        tooltip: '操作说明',
                        onPressed: _showInstructions,
                        icon: const Icon(Icons.info_outline_rounded,
                            color: vinylOlive, size: 22)),
                  ])),
              Expanded(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(children: [
                          Row(children: [
                            Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                    color: vinylOlive, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    _busy
                                        ? '正在取出唱片'
                                        : _scrubbing != null
                                            ? '正在转动唱片'
                                            : playing
                                                ? '唱针已落下 · 正在播放'
                                                : '唱针已抬起 · 等待聆听',
                                    style: const TextStyle(
                                        color: vinylOlive,
                                        fontSize: 11,
                                        letterSpacing: .5))),
                            const Text('SIDE A',
                                style: TextStyle(
                                    color: vinylOlive,
                                    fontSize: 10,
                                    letterSpacing: 2)),
                          ]),
                          const SizedBox(height: 16),
                          VinylDeck(
                              playing: playing,
                              position: state.now,
                              duration: state.length,
                              enabled: track != null,
                              busy: _busy,
                              unavailableDirection: _unavailableDirection,
                              previousTrack: previous,
                              nextTrack: next,
                              canSkipPrevious: index > 0,
                              canSkipNext:
                                  index >= 0 && index + 1 < queue.length,
                              cover: const CurrentTrackCover(
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover),
                              onArmChanged: _moveArm,
                              onSkip: _skip,
                              onLabelLongPress: _showPlaylists,
                              onLabelSwipeUp: _showQueue,
                              onLabelSwipeDown: _showSavePlaylists,
                              onSeek: (value) => _run(() => ref
                                  .read(playerStateNotifierProvider.notifier)
                                  .seek(value)),
                              onScrubChanged: (value) {
                                if (mounted) setState(() => _scrubbing = value);
                              }),
                          const SizedBox(height: 12),
                          RecordShelf(
                            count: queue.length,
                            busy: _busy,
                            covers: [
                              if (track != null)
                                TrackCover(track, fit: BoxFit.cover),
                              if (next != null) next.cover,
                              if (previous != null) previous.cover,
                            ],
                            onOpenQueue: _showQueue,
                            onChoosePlaylist: _showPlaylists,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                              key: const ValueKey('player-track-title'),
                              width: double.infinity,
                              height: textScaler.scale(24) * 1.35 * 2,
                              child: Center(
                                  child: Text(track?.title ?? '让音乐，慢慢转起来',
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      strutStyle: const StrutStyle(
                                          fontSize: 24,
                                          height: 1.35,
                                          forceStrutHeight: true),
                                      style: const TextStyle(
                                          color: vinylInk,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          height: 1.35,
                                          letterSpacing: -.5)))),
                          const SizedBox(height: 10),
                          SizedBox(
                              key: const ValueKey('player-track-singer'),
                              width: double.infinity,
                              height: textScaler.scale(15) * 1.4 + 14,
                              child: Center(
                                  child: singer.isEmpty
                                      ? const SizedBox.shrink()
                                      : Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 6),
                                          decoration: BoxDecoration(
                                              color:
                                                  vinylCream.withOpacity(.65),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: vinylOlive
                                                      .withOpacity(.24),
                                                  width: .8)),
                                          child: Text(singer,
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              strutStyle: const StrutStyle(
                                                  fontSize: 15,
                                                  height: 1.4,
                                                  forceStrutHeight: true),
                                              style: const TextStyle(
                                                  color: vinylInk,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.4))))),
                          if (_feedback != null) ...[
                            const SizedBox(height: 12),
                            Text(_feedback!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFF9B593D),
                                    fontSize: 11,
                                    height: 1.6)),
                          ],
                        ]))),
              )),
            ])));
  }
}

class _PlayerSurface extends StatelessWidget {
  const _PlayerSurface({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
      color: color,
      child: Stack(fit: StackFit.expand, children: [
        const Positioned.fill(
            child: IgnorePointer(
                child: ExcludeSemantics(
                    child: RepaintBoundary(child: PlayerBackground())))),
        SafeArea(child: child),
      ]));
}
