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
  });
  final int count;
  final List<Widget> covers;
  final VoidCallback onOpenQueue;
  final VoidCallback onChoosePlaylist;
  final VoidCallback? onSaveTrack;
  final bool busy;
  int get _sleeveCount => count.clamp(1, 3).toInt();

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
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(children: [
                  ExcludeSemantics(
                      child: SizedBox(
                    width: MediaQuery.sizeOf(context).width < 360 ? 56 : 82,
                    height: 58,
                    child: Stack(children: [
                      for (var index = _sleeveCount - 1; index >= 0; index--)
                        Positioned(
                          left: index * 12,
                          top: index * 3,
                          width: 52,
                          height: 52,
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
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('播放列表',
                          style: TextStyle(
                              color: vinylCream,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Text(
                          busy
                              ? '请稍候…'
                              : count == 0
                                  ? '还没有唱片'
                                  : '$count 张 · 点按翻看',
                          style: TextStyle(
                              color: vinylCream.withOpacity(.75),
                              fontSize: 10,
                              height: 1.4)),
                    ],
                  )),
                ]),
              ),
            ),
          ),
          Container(width: 1, height: 42, color: vinylCream.withOpacity(.18)),
          Semantics(
              button: true,
              enabled: !busy && onSaveTrack != null,
              label: '收藏到歌单',
              excludeSemantics: true,
              child: InkWell(
                key: const ValueKey('record-sleeve-save'),
                onTap: busy ? null : onSaveTrack,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bookmark_add_outlined,
                        color: onSaveTrack == null || busy
                            ? vinylGold.withOpacity(.4)
                            : vinylGold,
                        size: 22),
                    const SizedBox(height: 5),
                    const Text('收藏',
                        style: TextStyle(color: vinylCream, fontSize: 11)),
                  ]),
                ),
              )),
          InkWell(
            key: const ValueKey('record-shelf-playlists'),
            onTap: busy ? null : onChoosePlaylist,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 9, vertical: 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.library_music_outlined, color: vinylGold, size: 22),
                SizedBox(height: 5),
                Text('选歌单', style: TextStyle(color: vinylCream, fontSize: 11)),
              ]),
            ),
          ),
        ]),
      );
}
