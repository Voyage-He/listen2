import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';

class PlayerInstructions extends StatelessWidget {
  const PlayerInstructions({super.key, required this.onStartTutorial});

  final VoidCallback onStartTutorial;

  static const _instructions = [
    '01   点击唱机下方「选歌单」，或长按中央标签，选择歌曲。\n       也可以在首页唱片外左滑进入搜索，选择音乐。',
    '02   按住右下方唱头，抬起后拖动，唱针进入唱片即可吸附。\n       松手播放，移回支架松手暂停；未到位会复原。也可以轻点唱臂。',
    '03   沿外圈沟槽顺时针旋转快进，逆时针快退。\n       每转一圈调整 60 秒，松手后定位。',
    '04   中央标签左右拨动时可预览上一曲 / 下一曲。\n       出现「松手换」提示后松手切换，拖回则取消。',
    '05   点按唱机下方唱片架，或在中央标签上滑，查看队列。\n       中央标签下滑收藏，在列表选择本地歌单或「我喜欢的」。',
    '06   在首页唱片外的区域右滑进入设置，左滑进入搜索。',
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('像使用唱机一样聆听',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: vinylInk)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('start-player-tutorial'),
                  onPressed: onStartTutorial,
                  style: FilledButton.styleFrom(
                      backgroundColor: vinylOlive,
                      foregroundColor: vinylCream,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16)),
                  icon: const Icon(Icons.touch_app_outlined),
                  label: const Text('开始引导教程'),
                ),
              ),
              const SizedBox(height: 8),
              const Text('跟着高亮提示，亲手练习每一个动作。',
                  style: TextStyle(color: vinylOlive, height: 1.6)),
              const SizedBox(height: 24),
              for (var index = 0; index < _instructions.length; index++) ...[
                if (index > 0) const SizedBox(height: 16),
                Text(_instructions[index],
                    style: const TextStyle(height: 1.8, color: vinylInk)),
              ],
            ],
          ),
        ),
      );
}

enum _TutorialGesture { library, arm, grooves, skip, shelf, save, pages }

class _TutorialStep {
  const _TutorialStep(
      this.gesture, this.title, this.instruction, this.hint, this.success);

  final _TutorialGesture gesture;
  final String title;
  final String instruction;
  final String hint;
  final String success;
}

const _tutorialSteps = [
  _TutorialStep(_TutorialGesture.library, '先选一张唱片',
      '按住中央标签，打开歌单，再选择一张练习唱片。回到播放器后，也可以这样找到你的音乐。', '长按中央标签', '已选好练习唱片'),
  _TutorialStep(
      _TutorialGesture.arm,
      '让唱针落下',
      '按住右下方唱头，抬起后拖动，唱针进入唱片即可吸附，松手播放；移回支架吸附后松手暂停。未到位会复原，轻点唱臂也可以。',
      '按住唱头再拖动，吸附后松手；或轻点唱臂',
      '已学会控制唱针'),
  _TutorialStep(_TutorialGesture.grooves, '沿沟槽转动',
      '沿高亮的外圈顺时针转动，快进；逆时针转动，快退。每转一圈调整 60 秒，松手后定位。', '在外圈转动，松手定位', '已调整练习唱片的进度'),
  _TutorialStep(
      _TutorialGesture.skip,
      '拨到下一张',
      '在中央标签上向左拨动预览下一曲，向右预览上一曲。出现「松手换」提示后松手切换，拖回则取消。',
      '拨动标签，看到「松手换」后松手',
      '已切换练习唱片'),
  _TutorialStep(_TutorialGesture.shelf, '翻看唱片架',
      '在中央标签上向上滑动，打开当前播放队列。唱片架里的音乐会按歌单顺序播放。', '在中央标签上向上滑动', '已打开练习唱片架'),
  _TutorialStep(_TutorialGesture.save, '收藏这一首',
      '在中央标签上向下滑动，选择「我喜欢的」或本地歌单，就能收好当前歌曲。', '在中央标签上向下滑动', '已演示收藏到歌单'),
  _TutorialStep(_TutorialGesture.pages, '在唱片之外探索',
      '在唱片外的空白处向左滑动，进入搜索；向右滑动，进入设置。试着在唱片两侧滑动。', '在唱片外左右滑动', '已学会切换侧页'),
];

/// A local practice deck keeps the tutorial independent of playback and storage.
class PlayerTutorial extends StatefulWidget {
  const PlayerTutorial({super.key, this.isHome = false});

  final bool isHome;

  @override
  State<PlayerTutorial> createState() => _PlayerTutorialState();
}

class _PlayerTutorialState extends State<PlayerTutorial> {
  int _index = 0;
  int _recordIndex = 0;
  bool _playing = false;
  bool _completed = false;
  Duration _position = const Duration(seconds: 45);
  double _pageSwipe = 0;

  List<_TutorialStep> get _steps => widget.isHome
      ? _tutorialSteps
      : _tutorialSteps.sublist(0, _tutorialSteps.length - 1);
  _TutorialStep get _step => _steps[_index];

  void _complete(_TutorialGesture gesture) {
    if (_step.gesture == gesture) setState(() => _completed = true);
  }

  void _changeStep(int index) {
    setState(() {
      _index = index;
      _playing = false;
      _completed = false;
      _pageSwipe = 0;
    });
  }

  Future<void> _showPracticeSheet(_TutorialGesture gesture) async {
    final collecting = gesture == _TutorialGesture.save;
    final title = switch (gesture) {
      _TutorialGesture.library => '练习歌单',
      _TutorialGesture.shelf => '练习唱片架',
      _ => '练习收藏',
    };
    final items =
        collecting ? ['我喜欢的音乐', '练习歌单'] : ['练习唱片 A', '练习唱片 B', '练习唱片 C'];
    if (gesture == _TutorialGesture.shelf) _complete(gesture);
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: vinylCream,
      showDragHandle: true,
      isScrollControlled: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: vinylInk)),
              const SizedBox(height: 12),
              for (var index = 0; index < items.length; index++)
                ListTile(
                    leading: Icon(
                        collecting
                            ? Icons.favorite_border_rounded
                            : Icons.album_outlined,
                        color: vinylOlive),
                    title: Text(items[index]),
                    onTap: () => Navigator.of(context).pop(index)),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null || _step.gesture != gesture) return;
    setState(() {
      if (!collecting) _recordIndex = selected;
      _completed = true;
    });
  }

  Widget _practiceDeck() => LayoutBuilder(builder: (context, constraints) {
        final width = math
            .min(
                460.0,
                math.min(
                    constraints.maxWidth - 32,
                    (constraints.maxHeight - 16) *
                        VinylDeckGeometry.aspectRatio))
            .clamp(0.0, 460.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _pageSwipe = 0,
          onHorizontalDragUpdate: (details) => _pageSwipe += details.delta.dx,
          onHorizontalDragEnd: (_) {
            if (_pageSwipe.abs() >= 48) _complete(_TutorialGesture.pages);
            _pageSwipe = 0;
          },
          onHorizontalDragCancel: () => _pageSwipe = 0,
          child: Center(
            child: SizedBox(
              width: width,
              height: width / VinylDeckGeometry.aspectRatio,
              child: Stack(fit: StackFit.expand, children: [
                VinylDeck(
                  key: const ValueKey('tutorial-practice-deck'),
                  playing: _playing,
                  position: _position,
                  duration: const Duration(minutes: 3),
                  previousTrack: VinylTrackPreview(
                    title:
                        '练习唱片 ${String.fromCharCode(65 + (_recordIndex + 2) % 3)}',
                    cover: ColoredBox(
                        color: const [
                      Color(0xFFBC7354),
                      Color(0xFF657052),
                      Color(0xFFDBBE7E)
                    ][(_recordIndex + 2) % 3]),
                  ),
                  nextTrack: VinylTrackPreview(
                    title:
                        '练习唱片 ${String.fromCharCode(65 + (_recordIndex + 1) % 3)}',
                    cover: ColoredBox(
                        color: const [
                      Color(0xFFBC7354),
                      Color(0xFF657052),
                      Color(0xFFDBBE7E)
                    ][(_recordIndex + 1) % 3]),
                  ),
                  cover: ColoredBox(
                    color: const [
                      Color(0xFFBC7354),
                      Color(0xFF657052),
                      Color(0xFFDBBE7E),
                    ][_recordIndex],
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: .5,
                        heightFactor: .5,
                        child: FittedBox(
                          child: Text(String.fromCharCode(65 + _recordIndex),
                              style: const TextStyle(
                                  color: vinylCream,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                  onArmChanged: (lowered) async {
                    setState(() => _playing = lowered);
                    _complete(_TutorialGesture.arm);
                  },
                  onSeek: (position) async {
                    if (position == _position) return;
                    setState(() => _position = position);
                    _complete(_TutorialGesture.grooves);
                  },
                  onSkip: (direction) async {
                    setState(
                        () => _recordIndex = (_recordIndex + direction) % 3);
                    _complete(_TutorialGesture.skip);
                  },
                  onLabelLongPress: _step.gesture == _TutorialGesture.library
                      ? () => _showPracticeSheet(_TutorialGesture.library)
                      : null,
                  onLabelSwipeUp: _step.gesture == _TutorialGesture.shelf
                      ? () => _showPracticeSheet(_TutorialGesture.shelf)
                      : null,
                  onLabelSwipeDown: _step.gesture == _TutorialGesture.save
                      ? () => _showPracticeSheet(_TutorialGesture.save)
                      : null,
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CustomPaint(
                          painter: _TutorialHighlight(
                              _step.gesture, _playing, _position),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      });

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
        backgroundColor: vinylCream,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
              child: Row(children: [
                const Expanded(
                    child: Text('操作教程',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: vinylInk))),
                IconButton(
                    tooltip: '退出教程',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: vinylOlive)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LinearProgressIndicator(
                  value: (_index + 1) / _steps.length,
                  minHeight: 3,
                  color: vinylOlive,
                  backgroundColor: vinylOlive.withOpacity(.12),
                  semanticsLabel: '教程进度',
                  semanticsValue: '${_index + 1} / ${_steps.length}'),
            ),
            Expanded(child: _practiceDeck()),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .3),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Row(children: [
                        Text('第 ${_index + 1} / ${_steps.length} 步',
                            style: const TextStyle(
                                fontSize: 11, color: vinylOlive)),
                        const SizedBox(width: 10),
                        if (_completed) ...[
                          const Icon(Icons.check_circle_outline_rounded,
                              size: 15, color: vinylOlive),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                            child: Text(_completed ? _step.success : _step.hint,
                                maxLines: 2,
                                style: const TextStyle(
                                    fontSize: 11, color: vinylOlive))),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Text(_step.title,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: vinylInk)),
                    const SizedBox(height: 8),
                    Text(_step.instruction,
                        style: const TextStyle(
                            color: vinylInk, fontSize: 14, height: 1.6)),
                    const SizedBox(height: 10),
                    const Text('练习不会改变当前播放与收藏，也可以直接查看下一步。',
                        style: TextStyle(
                            color: vinylOlive, fontSize: 11, height: 1.5)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(children: [
                TextButton(
                    onPressed:
                        _index > 0 ? () => _changeStep(_index - 1) : null,
                    child: const Text('上一步')),
                const Spacer(),
                FilledButton(
                    onPressed: () {
                      if (_index == _steps.length - 1) {
                        Navigator.of(context).pop();
                      } else {
                        _changeStep(_index + 1);
                      }
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: vinylOlive,
                        foregroundColor: vinylCream,
                        minimumSize: const Size(112, 48)),
                    child: Text(_index == _steps.length - 1 ? '完成教程' : '下一步')),
              ]),
            ),
          ]),
        ),
      );
}

class _TutorialHighlight extends CustomPainter {
  const _TutorialHighlight(this.gesture, this.playing, this.position);

  final _TutorialGesture gesture;
  final bool playing;
  final Duration position;

  void _arrow(Canvas canvas, Offset start, Offset end, Paint paint,
      {bool bothEnds = false}) {
    canvas.drawLine(start, end, paint);
    void head(Offset from, Offset to) {
      final angle = math.atan2((to - from).dy, (to - from).dx);
      final length = math.min(12.0, (to - from).distance * .3);
      for (final offset in [-.6, .6]) {
        canvas.drawLine(
            to,
            to -
                Offset(math.cos(angle + offset), math.sin(angle + offset)) *
                    length,
            paint);
      }
    }

    head(start, end);
    if (bothEnds) head(end, start);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = VinylDeckGeometry(size);
    final record = geometry.record;
    final center = record.center;
    final labelRadius = record.width * .19;
    final progress =
        position.inMilliseconds / const Duration(minutes: 3).inMilliseconds;
    final tip = geometry.tip(playing ? 1 : 0, progress);
    final focus = Path();
    switch (gesture) {
      case _TutorialGesture.grooves:
        focus
          ..fillType = PathFillType.evenOdd
          ..addOval(record)
          ..addOval(
              Rect.fromCircle(center: center, radius: record.width * .29));
      case _TutorialGesture.arm:
        focus.addRRect(RRect.fromRectAndRadius(
            Rect.fromPoints(geometry.pivot, tip).inflate(size.width * .07),
            const Radius.circular(18)));
      case _TutorialGesture.pages:
        focus
          ..addRect(Rect.fromLTWH(0, 0, size.width * .09, size.height))
          ..addRect(Rect.fromLTWH(
              size.width * .91, 0, size.width * .09, size.height));
      default:
        focus.addOval(Rect.fromCircle(center: center, radius: labelRadius));
    }
    canvas.drawPath(
        Path.combine(PathOperation.difference,
            Path()..addRect(Offset.zero & size), focus),
        Paint()..color = vinylInk.withOpacity(.48));
    final guide = Paint()
      ..color = vinylGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(focus, guide);
    switch (gesture) {
      case _TutorialGesture.library:
        canvas.drawCircle(center, labelRadius * .25, guide);
        canvas.drawCircle(
            center, labelRadius * .08, Paint()..color = vinylGold);
      case _TutorialGesture.arm:
        _arrow(canvas, geometry.parkedTip, geometry.tip(1, progress), guide);
      case _TutorialGesture.grooves:
        final arc = record.deflate(record.width * .09);
        const start = -math.pi * .85;
        const sweep = math.pi * 1.3;
        canvas.drawArc(arc, start, sweep, false, guide);
        const angle = start + sweep;
        final end =
            center + Offset(math.cos(angle), math.sin(angle)) * (arc.width / 2);
        _arrow(canvas, end - Offset(-math.sin(angle), math.cos(angle)) * 16,
            end, guide);
      case _TutorialGesture.skip:
        _arrow(canvas, center - Offset(labelRadius * .65, 0),
            center + Offset(labelRadius * .65, 0), guide,
            bothEnds: true);
      case _TutorialGesture.shelf:
        _arrow(canvas, center + Offset(0, labelRadius * .65),
            center - Offset(0, labelRadius * .65), guide);
      case _TutorialGesture.save:
        _arrow(canvas, center - Offset(0, labelRadius * .65),
            center + Offset(0, labelRadius * .65), guide);
      case _TutorialGesture.pages:
        for (final direction in [-1, 1]) {
          final side =
              Offset(size.width * (direction < 0 ? .09 : .91), center.dy);
          _arrow(canvas, side - Offset(size.width * .055 * direction, 0),
              side + Offset(size.width * .055 * direction, 0), guide);
        }
    }
  }

  @override
  bool shouldRepaint(_TutorialHighlight oldDelegate) =>
      gesture != oldDelegate.gesture ||
      playing != oldDelegate.playing ||
      position != oldDelegate.position;
}
