import 'package:flutter/material.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';

/// A paper catalog and a brass plaque remain visible beside the record player.
class PlayerRoomNavigation extends StatelessWidget {
  const PlayerRoomNavigation(
      {super.key, required this.onSearch, required this.onSettings});
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: _RoomObject(
          key: const ValueKey('player-search-entry'),
          label: '找音乐',
          icon: Icons.search_rounded,
          colors: const [Color(0xFFF9F3E6), Color(0xFFE8DEC8)],
          onTap: onSearch,
        )),
        const SizedBox(width: 12),
        Expanded(
            child: _RoomObject(
          key: const ValueKey('player-settings-entry'),
          label: '设置',
          icon: Icons.tune_rounded,
          colors: const [Color(0xFFEEE0BA), Color(0xFFCBB58A)],
          onTap: onSettings,
        )),
      ]);
}

class _RoomObject extends StatelessWidget {
  const _RoomObject(
      {super.key,
      required this.label,
      required this.icon,
      required this.colors,
      required this.onTap});
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: vinylOlive.withOpacity(.25)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x16000000), blurRadius: 5, offset: Offset(0, 3))
          ],
        ),
        child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: onTap,
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 19, color: vinylInk),
                        const SizedBox(width: 8),
                        Flexible(
                            child: Text(label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: vinylInk,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500))),
                      ])),
            )),
      );
}
