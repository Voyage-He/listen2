import 'package:flutter/material.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';

/// Exposed sleeves make the queue and library discoverable without a gesture.
class RecordShelf extends StatelessWidget {
  const RecordShelf({
    super.key,
    required this.count,
    required this.covers,
    required this.onOpenQueue,
    required this.onChoosePlaylist,
    this.onSaveTrack,
    this.busy = false,
    this.compact = false,
  });
  final int count;
  final List<Widget> covers;
  final VoidCallback onOpenQueue;
  final VoidCallback onChoosePlaylist;
  final VoidCallback? onSaveTrack;
  final bool busy;
  final bool compact;
  int get _sleeveCount => count.clamp(1, 3).toInt();

  Widget _fit(Widget child) =>
      compact ? FittedBox(fit: BoxFit.scaleDown, child: child) : child;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF66513E),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          Expanded(
            child: InkWell(
              key: const ValueKey('record-shelf-open'),
              onTap: busy ? null : onOpenQueue,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    12, compact ? 6 : 12, 8, compact ? 6 : 12),
                child: Row(children: [
                  ExcludeSemantics(
                      child: SizedBox(
                    width: compact || MediaQuery.sizeOf(context).width < 360
                        ? 56
                        : 82,
                    height: compact ? 40 : 58,
                    child: Stack(children: [
                      for (var index = _sleeveCount - 1; index >= 0; index--)
                        Positioned(
                          left: index * (compact ? 10 : 12),
                          top: index * (compact ? 2 : 3),
                          width: compact ? 34 : 52,
                          height: compact ? 34 : 52,
                          child: Transform.rotate(
                            angle: (index - 1) * .09,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: [
                                  vinylCream,
                                  vinylGold,
                                  const Color(0xFF96A080)
                                ][index],
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x44000000),
                                      blurRadius: 4,
                                      offset: Offset(1, 2))
                                ],
                              ),
                              child: index < covers.length
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: covers[index])
                                  : const Icon(Icons.album_outlined,
                                      color: vinylOlive, size: 24),
                            ),
                          ),
                        ),
                      Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              color: const Color(0xFF9B7A55),
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                  color: const Color(0xFFBBA17C), width: .6),
                            ),
                          )),
                    ]),
                  )),
                  const SizedBox(width: 10),
                  Expanded(
                      child: LayoutBuilder(builder: (context, constraints) {
                    final labels = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('播放列表',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: vinylCream,
                                fontSize: compact ? 12 : 14,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: compact ? 2 : 5),
                        Text(
                            busy
                                ? '请稍候…'
                                : count == 0
                                    ? '还没有唱片'
                                    : '$count 张 · 点按翻看',
                            maxLines: compact ? 1 : null,
                            overflow: compact ? TextOverflow.ellipsis : null,
                            style: TextStyle(
                                color: vinylCream.withOpacity(.75),
                                fontSize: compact ? 9 : 10,
                                height: 1.4)),
                      ],
                    );
                    return compact
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                                width: constraints.maxWidth, child: labels))
                        : labels;
                  })),
                ]),
              ),
            ),
          ),
          Container(
              width: 1,
              height: compact ? 30 : 42,
              color: vinylCream.withOpacity(.18)),
          Semantics(
              button: true,
              enabled: !busy && onSaveTrack != null,
              label: '收藏到歌单',
              excludeSemantics: true,
              child: InkWell(
                key: const ValueKey('record-sleeve-save'),
                onTap: busy ? null : onSaveTrack,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 13, vertical: compact ? 6 : 16),
                  child: _fit(Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bookmark_add_outlined,
                        color: onSaveTrack == null || busy
                            ? vinylGold.withOpacity(.4)
                            : vinylGold,
                        size: compact ? 20 : 22),
                    SizedBox(height: compact ? 2 : 5),
                    const Text('收藏',
                        style: TextStyle(color: vinylCream, fontSize: 11)),
                  ])),
                ),
              )),
          InkWell(
            key: const ValueKey('record-shelf-playlists'),
            onTap: busy ? null : onChoosePlaylist,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 9, vertical: compact ? 6 : 16),
              child: _fit(Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.library_music_outlined,
                    color: vinylGold, size: compact ? 20 : 22),
                SizedBox(height: compact ? 2 : 5),
                const Text('选歌单',
                    style: TextStyle(color: vinylCream, fontSize: 11)),
              ])),
            ),
          ),
        ]),
      );
}
