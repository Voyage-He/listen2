import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/player.dart';
import 'package:listen2/src/provider/global/current_playlist.dart';
import 'package:listen2/src/provider/global/player_hints.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:listen2/src/view/page/search/search.page.dart';
import 'package:listen2/src/widget/track_cover.widget.dart';
import 'package:listen2/src/widget/player_background.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';
import 'package:listen2/src/widget/playlist_picker.dart';
import 'package:listen2/src/widget/player_tutorial.dart';
import 'package:listen2/src/widget/record_shelf.dart';
import 'package:listen2/src/widget/player_room_navigation.dart';
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
  Duration _scrubOrigin = Duration.zero;
  Future<void>? _scrubBegin;
  PlayerStateNotifier? _scrubPlayer;
  String? _contextHint;
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

  void _markHint(String key) {
    if (!mounted) return;
    unawaited(ref
        .read(playerHintsProvider.notifier)
        .markSeen(key)
        .catchError((_) {}));
    if (_contextHint == key) setState(() => _contextHint = null);
  }

  void _beginScrub() {
    if (_scrubActive || _busy) return;
    final playback = ref.read(playerStateNotifierProvider);
    _scrubPlayer = ref.read(playerStateNotifierProvider.notifier);
    setState(() {
      _scrubActive = true;
      _scrubWasPlaying = playback.state == ap.PlayerState.playing;
      _scrubOrigin = playback.now;
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
        if (value != _scrubOrigin) _markHint('grooves');
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
      _markHint('arm');
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
      _markHint('skip');
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
    _markHint('intro');
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            PlaylistPage(playlistName: name, returnToPlayerOnPlay: true)));
  }

  void _showQueue() {
    final showHint = !ref.read(playerHintsProvider).contains('queue');
    _markHint('queue');
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
                  if (showHint)
                    const Padding(
                        padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: Text('点选歌曲即可播放；用「选歌单」切换整份播放列表。',
                            style: TextStyle(
                                color: vinylOlive, fontSize: 12, height: 1.5))),
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
    final seenHints = ref.watch(playerHintsProvider);
    final hintKey = _contextHint != null && !seenHints.contains(_contextHint)
        ? _contextHint
        : track == null && !seenHints.contains('intro')
            ? 'intro'
            : track != null && !playing && !seenHints.contains('arm')
                ? 'arm'
                : null;
    final hint = switch (hintKey) {
      'intro' => '先选一首音乐，再把唱针放上唱片。',
      'arm' => '按住唱头片刻再拖动，或轻点唱臂播放。',
      'grooves' => '顺时针快进，逆时针快退；松手定位。',
      'skip' => '看到「松手换」后松手；拖回即可取消。',
      _ => null,
    };
    final textScaler = MediaQuery.textScalerOf(context);
    final reservedHeight = 44 +
        textScaler.scale(11) * 1.4 +
        16 +
        (widget.isHome
            ? math.max(45, textScaler.scale(12) * 1.4 + 26) + 12
            : 0) +
        math.max(
            82, textScaler.scale(14) * 1.4 + textScaler.scale(10) * 2.8 + 29) +
        textScaler.scale(12) * 3.7 +
        8 +
        textScaler.scale(24) * 2.7 +
        10 +
        textScaler.scale(15) * 1.4 +
        14 +
        12;
    // Reserve room for the controls and track info while retaining a usable touch size.
    final deckWidth = math.min(
        460.0,
        math.max(
            260.0,
            (MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).vertical -
                    68 -
                    reservedHeight) *
                VinylDeckGeometry.aspectRatio));
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
                                        ? _busyLabel
                                        : state.loading
                                            ? '等待音乐加载'
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
                          if (widget.isHome) ...[
                            PlayerRoomNavigation(
                              onSearch: () => _openSidePage(-1),
                              onSettings: () => _openSidePage(1),
                            ),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                              width: deckWidth,
                              child: VinylDeck(
                                  playing: deckPlaying,
                                  position: state.now,
                                  duration: state.length,
                                  enabled: track != null,
                                  busy: _busy || state.loading,
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
                                  onSeek: _seek,
                                  onScrubStart: _beginScrub,
                                  onScrubCancel: () =>
                                      unawaited(_cancelScrub()),
                                  onInteraction: (interaction) {
                                    final key =
                                        interaction == VinylInteraction.scrub
                                            ? 'grooves'
                                            : 'skip';
                                    if (!seenHints.contains(key)) {
                                      setState(() => _contextHint = key);
                                    }
                                  },
                                  onScrubChanged: (value) {
                                    if (mounted) {
                                      setState(() => _scrubbing = value);
                                    }
                                  })),
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
                            onSaveTrack:
                                track == null ? null : _showSavePlaylists,
                          ),
                          SizedBox(
                              height: textScaler.scale(12) * 3.7,
                              child: Row(children: [
                                Expanded(
                                    child: Text(
                                        hint ??
                                            (track == null
                                                ? '选择音乐，开始聆听'
                                                : '${vinylTime(_scrubbing ?? state.now)} / ${vinylTime(state.length)}'),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: vinylOlive,
                                            fontSize: 12,
                                            height: 1.5))),
                                if (hint != null)
                                  IconButton(
                                      tooltip: '隐藏提示',
                                      onPressed: () => _markHint(hintKey!),
                                      icon: const Icon(Icons.close_rounded,
                                          color: vinylOlive, size: 16)),
                              ])),
                          const SizedBox(height: 8),
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
                            if (_retry != null)
                              TextButton.icon(
                                  onPressed: _busy ? null : _retry,
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 18),
                                  label: const Text('重试')),
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
