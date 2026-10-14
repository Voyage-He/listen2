import 'dart:async';
import 'dart:math' as math;
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
  String _busyLabel = '正在取出唱片';
  Future<void> Function()? _retry;
  bool _scrubActive = false;
  bool _scrubWasPlaying = false;
  Future<void>? _scrubBegin;
  PlayerStateNotifier? _scrubPlayer;
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
    final player = _scrubPlayer;
    final begin = _scrubBegin;
    if (_scrubActive && player != null) {
      unawaited(() async {
        try {
          await begin;
          await player.finishScrub();
        } catch (_) {}
      }());
    }
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

  Future<void> _run(
    Future<void> Function() action, {
    String message = '正在取出唱片',
    String error = '这张唱片暂时无法播放',
  }) async {
    if (_busy) return;
    _edgeFeedbackTimer?.cancel();
    setState(() {
      _unavailableDirection = null;
      _busy = true;
      _busyLabel = message;
      _feedback = null;
      _retry = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedback = error;
          _retry = () => _run(action, message: message, error: error);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _beginScrub() {
    if (_scrubActive || _busy) return;
    final playback = ref.read(playerStateNotifierProvider);
    _scrubPlayer = ref.read(playerStateNotifierProvider.notifier);
    setState(() {
      _scrubActive = true;
      _scrubWasPlaying = playback.state == ap.PlayerState.playing;
    });
    _scrubBegin = _scrubPlayer!.beginScrub();
    unawaited(_scrubBegin!.catchError((_) {}));
  }

  Future<void> _seek(Duration value) async {
    try {
      await _run(() async {
        if (_scrubActive) {
          await _scrubBegin;
          await _scrubPlayer!.finishScrub(value);
        } else {
          await ref.read(playerStateNotifierProvider.notifier).seek(value);
        }
      }, message: '正在定位 · ${vinylTime(value)}', error: '定位失败，请重试');
    } finally {
      _clearScrub();
    }
  }

  void _clearScrub() {
    if (!mounted) return;
    setState(() {
      _scrubActive = false;
      _scrubBegin = null;
      _scrubPlayer = null;
      _scrubbing = null;
    });
  }

  Future<void> _cancelScrub() async {
    if (!_scrubActive) return;
    try {
      await _run(() async {
        if (_scrubActive) {
          await _scrubBegin;
          await _scrubPlayer!.finishScrub();
        } else if (_scrubWasPlaying) {
          await ref.read(playerStateNotifierProvider.notifier).resume();
        }
      }, message: '正在放开唱片', error: '暂时无法恢复播放，请重试');
    } finally {
      _clearScrub();
    }
  }

  Future<void> _moveArm(bool lowered) async {
    if (_scrubActive) {
      await _scrubPlayer!.cancelScrub();
      _clearScrub();
      if (!mounted) return;
    }
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
    },
        message: lowered ? '正在落针播放' : '正在抬针暂停',
        error: lowered ? '这张唱片暂时无法播放' : '暂时无法暂停，请重试');
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
                            child: Text('播放列表',
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
    final deckPlaying = _scrubActive ? _scrubWasPlaying : playing;
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
    final status = _busy
        ? _busyLabel
        : state.loading
            ? '等待音乐加载'
            : _scrubbing != null
                ? '正在转动唱片'
                : playing
                    ? '唱针已落下 · 正在播放'
                    : '唱针已抬起 · 等待聆听';
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
          SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                if (widget.isHome)
                  const SizedBox(width: 44)
                else
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: vinylInk),
                  ),
                const Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('LISTEN 2',
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 3,
                              color: vinylInk,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('THE RECORD ROOM',
                          style: TextStyle(
                              fontSize: 7,
                              letterSpacing: 2,
                              color: vinylOlive)),
                    ]),
                  ),
                ),
                IconButton(
                  tooltip: '操作说明',
                  onPressed: _showInstructions,
                  icon: const Icon(Icons.info_outline_rounded,
                      color: vinylOlive, size: 20),
                ),
              ]),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: LayoutBuilder(builder: (context, constraints) {
                final beside =
                    constraints.maxWidth >= 620 && constraints.maxHeight < 760;
                final deckWidth = math.min(460.0,
                    beside ? constraints.maxWidth * .6 : constraints.maxWidth);
                final deck = SizedBox(
                  width: deckWidth,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      height: 18,
                      child: Row(children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                              color: vinylOlive, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                            child: _FitPlayerText(status,
                                fontSize: 10, alignment: Alignment.centerLeft)),
                        const SizedBox(width: 8),
                        const SizedBox(
                            width: 48,
                            child: _FitPlayerText('SIDE A', fontSize: 9)),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    VinylDeck(
                      playing: deckPlaying,
                      position: state.now,
                      duration: state.length,
                      enabled: track != null,
                      busy: _busy || state.loading,
                      unavailableDirection: _unavailableDirection,
                      previousTrack: previous,
                      nextTrack: next,
                      canSkipPrevious: index > 0,
                      canSkipNext: index >= 0 && index + 1 < queue.length,
                      cover: const CurrentTrackCover(
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover),
                      onArmChanged: _moveArm,
                      onSkip: _skip,
                      onLabelLongPress: _showPlaylists,
                      onLabelSwipeUp: _showQueue,
                      onLabelSwipeDown: _showSavePlaylists,
                      onSeek: _seek,
                      onScrubStart: _beginScrub,
                      onScrubCancel: () => unawaited(_cancelScrub()),
                      onScrubChanged: (value) {
                        if (mounted) setState(() => _scrubbing = value);
                      },
                    ),
                  ]),
                );
                final controls = _PlayerControls(
                  shelf: RecordShelf(
                    compact: true,
                    count: queue.length,
                    busy: _busy,
                    covers: [
                      if (track != null) TrackCover(track, fit: BoxFit.cover),
                      if (next != null) next.cover,
                      if (previous != null) previous.cover,
                    ],
                    onOpenQueue: _showQueue,
                    onChoosePlaylist: _showPlaylists,
                    onSaveTrack: track == null ? null : _showSavePlaylists,
                  ),
                  progress:
                      '${vinylTime(_scrubbing ?? state.now)} / ${vinylTime(state.length)}',
                  title: track?.title ?? '让音乐，慢慢转起来',
                  singer: singer,
                  feedback: _feedback,
                  retry: _busy ? null : _retry,
                );
                if (beside) {
                  return Row(children: [
                    deck,
                    const SizedBox(width: 16),
                    Expanded(child: controls),
                  ]);
                }
                return Center(
                  child: SizedBox(
                    width: deckWidth,
                    child: Column(children: [
                      deck,
                      const SizedBox(height: 8),
                      Expanded(child: controls),
                    ]),
                  ),
                );
              }),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FitPlayerText extends StatelessWidget {
  const _FitPlayerText(
    this.text, {
    required this.fontSize,
    this.maxLines = 1,
    this.alignment = Alignment.center,
    this.color = vinylOlive,
    this.weight = FontWeight.normal,
  });
  final String text;
  final double fontSize;
  final int maxLines;
  final Alignment alignment;
  final Color color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: alignment == Alignment.centerLeft
                  ? TextAlign.left
                  : TextAlign.center,
              style: TextStyle(
                  color: color,
                  fontSize: fontSize,
                  fontWeight: weight,
                  height: 1.3),
            ),
          ),
        ),
      );
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({
    required this.shelf,
    required this.progress,
    required this.title,
    required this.singer,
    this.feedback,
    this.retry,
  });
  final Widget shelf;
  final String progress;
  final String title;
  final String singer;
  final String? feedback;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(height: 52, child: shelf),
        const SizedBox(height: 4),
        SizedBox(
            height: 44,
            child: Row(children: [
              Expanded(
                  child: _FitPlayerText(feedback ?? progress,
                      fontSize: 11,
                      maxLines: 2,
                      alignment: Alignment.centerLeft,
                      color: feedback == null
                          ? vinylOlive
                          : const Color(0xFF9B593D))),
              if (feedback != null && retry != null)
                TextButton.icon(
                    onPressed: retry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('重试'))
            ])),
        const SizedBox(height: 4),
        Expanded(
            flex: 3,
            child: SizedBox(
              key: const ValueKey('player-track-title'),
              width: double.infinity,
              child: _FitPlayerText(title,
                  fontSize: 20,
                  maxLines: 2,
                  color: vinylInk,
                  weight: FontWeight.w600),
            )),
        Expanded(
            child: SizedBox(
          key: const ValueKey('player-track-singer'),
          width: double.infinity,
          child: singer.isEmpty
              ? const SizedBox.shrink()
              : LayoutBuilder(
                  builder: (context, constraints) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: constraints.maxWidth - 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: vinylCream.withOpacity(.65),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: vinylOlive.withOpacity(.24), width: .8),
                        ),
                        child: Text(singer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: vinylInk,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.3)),
                      ),
                    ),
                  ),
                ),
        )),
      ]);
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
