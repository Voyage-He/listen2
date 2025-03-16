import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Colors, Icons, Theme;
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/player.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:listen2/src/view/page/option/option.page.dart';
import 'package:listen2/src/widget/button/button.dart';
import 'package:listen2/src/widget/popup.dart';
import 'package:listen2/src/ref_extensions.dart';

import '../search/search.page.dart';
import '../favorite/favorite.page.dart';
import '../player/player.page.dart';

import '../../../widget/track_cover.widget.dart';
import 'package:listen2/src/widget/bottom_player.dart';

class Home extends StatelessWidget {
  // final _popupKey = GlobalKey<PopupState>();

  Home({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (e) {
        print(e);
        // _popupKey.currentState!.open();
      },
      child: Stack(children: [
        Column(
          children: [
            const Header(),
            Expanded(child: _favoriteButton(context)),
          ],
        ),
        // Popup(Container(), key: _popupKey)
      ]),
    );
  }

  Widget _favoriteButton(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      GestureDetector(
          onTap: () => _navigate2FavoritePage(context),
          child: const Icon(
            Icons.favorite,
            color: Colors.redAccent,
            size: 40,
          )),
      Text('收藏', style: Theme.of(context).textTheme.headlineSmall)
    ]);
  }

  void _navigate2FavoritePage(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (context, _, __) => FavoratePage(),
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