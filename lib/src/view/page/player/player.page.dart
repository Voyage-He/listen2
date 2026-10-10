import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/player.dart';
import 'package:listen2/src/provider/global/current_playlist.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:listen2/src/view/page/search/search.page.dart';
import 'package:listen2/src/widget/track_cover.widget.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';
import 'package:listen2/src/widget/playlist_picker.dart';
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

  String _time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

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
      setState(() => _feedback = '先从音乐库选择一张唱片');
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
    final playback = ref.read(playerStateNotifierProvider);
    final track = playback.track;
    if (track == null) return;
    final queue = ref.read(currentPlaylistNotifierProvider).playlist;
    final index = queue.indexOf(track.bvid);
    final next = index + direction;
    if (index < 0 || next < 0 || next >= queue.length) {
      _showUnavailable(direction);
      return;
    }
    await _run(() => ref.read(currentPlaylistNotifierProvider.notifier).play(
        queue[next], queue,
        autoplay: playback.state == ap.PlayerState.playing));
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
                  const Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Text('唱片架',
                          style: TextStyle(
                              color: vinylInk,
                              fontSize: 22,
                              fontWeight: FontWeight.w600))),
                  Expanded(
                      child: ids.isEmpty
                          ? const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('从歌单选择音乐，唱片会按顺序放入这里',
                                      textAlign: TextAlign.center)))
                          : ListView.builder(
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
                                            overflow: TextOverflow.ellipsis),
                                        subtitle: Text(item.singer,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _run(() => ref
                                              .read(
                                                  currentPlaylistNotifierProvider
                                                      .notifier)
                                              .play(ids[index], ids));
                                        }),
                                    loading: () =>
                                        const ListTile(title: Text('正在取出唱片…')),
                                    error: (_, __) => ListTile(
                                        title: const Text('唱片加载失败'),
                                        trailing: IconButton(
                                            tooltip: '重试',
                                            icon: const Icon(Icons.refresh),
                                            onPressed: () => ref.invalidate(
                                                trackProvider(ids[index])))),
                                  ))),
                ]);
          })),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerStateNotifierProvider);
    final track = state.track;
    final playing = state.state == ap.PlayerState.playing;
    final favorite = track != null &&
        ref.watch(playlistIdsNotifierProvider('favorite')).contains(track.bvid);
    final position = _scrubbing ?? state.now;
    return Material(
        color: vinylCream,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(children: [
                IconButton(
                    tooltip: widget.isHome ? '设置' : '返回',
                    onPressed: () {
                      if (widget.isHome) {
                        Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const Option()));
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: Icon(
                        widget.isHome
                            ? Icons.tune_rounded
                            : Icons.keyboard_arrow_down_rounded,
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
                          fontSize: 8, letterSpacing: 2, color: vinylOlive)),
                ])),
                IconButton(
                    tooltip: '操作说明',
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: vinylCream,
                        showDragHandle: true,
                        isScrollControlled: true,
                        builder: (_) => const SafeArea(
                            child: SingleChildScrollView(
                                child: Padding(
                                    padding: EdgeInsets.fromLTRB(28, 4, 28, 36),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('像使用唱机一样聆听',
                                              style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w600,
                                                  color: vinylInk)),
                                          SizedBox(height: 24),
                                          Text(
                                              '01   把唱针向左移到唱片上，开始播放。\n       向右移回支架，暂停播放。也可以轻点唱臂。',
                                              style: TextStyle(
                                                  height: 1.8,
                                                  color: vinylInk)),
                                          SizedBox(height: 16),
                                          Text(
                                              '02   沿外圈沟槽顺时针旋转快进，逆时针快退。\n       每转一圈调整 60 秒，松手后定位。',
                                              style: TextStyle(
                                                  height: 1.8,
                                                  color: vinylInk)),
                                          SizedBox(height: 16),
                                          Text(
                                              '03   在中央标签上向左拨换下一曲，向右拨换上一曲。\n       唱片架中的音乐按歌单顺序播放。',
                                              style: TextStyle(
                                                  height: 1.8,
                                                  color: vinylInk)),
                                        ]))))),
                    icon: const Icon(Icons.info_outline_rounded,
                        color: vinylOlive, size: 22)),
              ])),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
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
                      const SizedBox(height: 22),
                      VinylDeck(
                          playing: playing && !_busy,
                          position: state.now,
                          duration: state.length,
                          enabled: track != null,
                          busy: _busy,
                          unavailableDirection: _unavailableDirection,
                          cover: const CurrentTrackCover(
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover),
                          onArmChanged: _moveArm,
                          onSkip: _skip,
                          onLabelLongPress: _showPlaylists,
                          onSeek: (value) => _run(() => ref
                              .read(playerStateNotifierProvider.notifier)
                              .seek(value)),
                          onScrubChanged: (value) {
                            if (mounted) setState(() => _scrubbing = value);
                          }),
                      const SizedBox(height: 28),
                      Text(track?.title ?? '让音乐，慢慢转起来',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: vinylInk,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              letterSpacing: -.5)),
                      const SizedBox(height: 10),
                      Text(track?.singer ?? '选择一张唱片，放下唱针',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: vinylOlive, fontSize: 13)),
                      const SizedBox(height: 24),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_time(position),
                                style: const TextStyle(
                                    color: vinylInk,
                                    fontSize: 17,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ])),
                            const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Text('/',
                                    style: TextStyle(
                                        color: Color(0xFFB1B2A5),
                                        fontSize: 13))),
                            Text(_time(state.length),
                                style: const TextStyle(
                                    color: vinylOlive,
                                    fontSize: 17,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ])),
                          ]),
                      const SizedBox(height: 12),
                      Text(_feedback ?? '外圈旋转定位 · 中央左右拨动换曲',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _feedback == null
                                  ? vinylOlive
                                  : const Color(0xFF9B593D),
                              fontSize: 11,
                              height: 1.6)),
                      const SizedBox(height: 26),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _accessory(
                                favorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                '收藏',
                                track == null
                                    ? null
                                    : () => ref
                                        .read(playlistIdsNotifierProvider(
                                                'favorite')
                                            .notifier)
                                        .toggle(track.bvid)),
                            _accessory(
                                Icons.library_music_outlined,
                                '选唱片',
                                () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const Search()))),
                            _accessory(
                                Icons.queue_music_rounded, '唱片架', _showQueue),
                          ]),
                    ]))),
          )),
        ]));
  }

  Widget _accessory(IconData icon, String label, VoidCallback? onTap) =>
      Column(children: [
        IconButton(
            tooltip: label,
            onPressed: onTap,
            icon: Icon(icon),
            color: vinylInk,
            disabledColor: const Color(0xFFB7B9AA),
            style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFE7E6DC),
                padding: const EdgeInsets.all(14))),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: vinylOlive, fontSize: 10)),
      ]);
}
