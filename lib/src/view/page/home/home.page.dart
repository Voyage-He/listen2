import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Colors, Icons, Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/repo/playlist_names.dart';
import 'package:listen2/src/view/page/option/option.page.dart';
import 'package:listen2/src/widget/button/button.dart';

import '../search/search.page.dart';
import '../playlist/playlist.dart';

class Home extends ConsumerWidget {
  // final _popupKey = GlobalKey<PopupState>();

  Home({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistNames = ref.watch(playlistNamesProvider);
    return GestureDetector(
      onVerticalDragUpdate: (e) {
        print(e);
        // _popupKey.currentState!.open();
      },
      child: Stack(children: [
        Column(
          children: [
            const Header(),
            Expanded(child: ListView.builder(
              itemCount: playlistNames.valueOrNull?.length ?? 0,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
                  child: PlaylistItem(name: playlistNames.valueOrNull?[index] ?? '', ref: ref),
                );
              },
            )),
          ],
        ),
        // Popup(Container(), key: _popupKey)
      ]),
    );
  }
}

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: Offset(0, 7),
              blurRadius: 10.0,
              spreadRadius: -5)
        ]),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Button(
              onTap: () {
                Navigator.of(context).push(PageRouteBuilder(
                  pageBuilder: (context, _, __) => const Option(),
                  // transitionDuration: const Duration(milliseconds: 2000),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(-1.0, 0.0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                ));
              },
              child: const Text('选项')),
          _SearchButton(context)
        ]));
  }

  Widget _SearchButton(BuildContext context) {
    return GestureDetector(
        onTap: () => _navigate2SearchPage(context),
        child: Icon(Icons.search, size: 30));
  }

  void _navigate2SearchPage(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (context, _, __) => const Search(),
      // transitionDuration: const Duration(milliseconds: 2000),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
    ));
  }
}

class PlaylistItem extends ConsumerWidget {
  const PlaylistItem({super.key, required this.name, required this.ref});
  final String name;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _navigate2PlaylistPage(context, name),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
        child: Row(
          children: [
            Expanded(child: Text(name)),
            // const Spacer(),
            name == 'favorite' ? const SizedBox() :
            GestureDetector(
              onDoubleTap: () => ref.read(playlistNamesProvider.notifier).toggle(name),
              onTap: () {},
              behavior: HitTestBehavior.deferToChild,
              child: Icon(Icons.delete, size: 30)),
          ],
        ),
      ),
    );
  }

  void _navigate2PlaylistPage(BuildContext context, String playlistName) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (context, _, __) => PlaylistPage(playlistName: playlistName),
      // transitionDuration: const Duration(milliseconds: 2000),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(  
            begin: const Offset(2.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
    ));
  }
}