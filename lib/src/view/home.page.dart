import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Colors, Icons, Theme;
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/stateful/player.dart';
import 'package:listen2/src/provider/stateful/track.dart';

import 'search.page.dart';
import 'favorite.page.dart';
import 'player.page.dart';

import './track_cover.widget.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        // decoration: const BoxDecoration(color: Colors.white),
        child: Stack(
      children: [
        const Align(alignment: Alignment.topCenter, child: Header()),
        Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(5, 40 + 10, 5, 50),
            child: _FavoriteButton(context)),
        const Align(
          alignment: Alignment.bottomCenter,
          child: BottomPlayer(),
        )
      ],
    ));
  }

  Widget _FavoriteButton(BuildContext context) {
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
      pageBuilder: (context, _, __) => const FavoratePage(),
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
        child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_SearchButton(context)]));
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

class BottomPlayer extends ConsumerWidget {
  const BottomPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var track = ref.watch(playerStateNotifierProvider.select((it) => it.track));
    return GestureDetector(
      onTap: () => _navigate2PlayerPage(context, track),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Color.fromARGB(80, 0, 0, 0),
              offset: Offset(0, 0),
              blurRadius: 10.0,
              spreadRadius: 0.0)
        ]),
        child: Row(
          children: [
            _cover(),
            _title(track),
            _controlButton(ref),
            const Icon(
              Icons.list,
              size: 40,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover() {
    return const CurrentTrackCover(width: 50, height: 50);
  }

  Widget _title(Track? track) {
    return Expanded(
        child: Text(track?.title ?? '',
            style: const TextStyle(
                fontSize: 20, overflow: TextOverflow.ellipsis)));
  }

  Widget _controlButton(WidgetRef ref) {
    var playerState = ref.watch(playerStateNotifierProvider);
    final isPlaying = playerState.state == ap.PlayerState.playing;
    // print('controlbutton$isPlaying');
    return GestureDetector(
        onTap: () {
          final player = ref.read(playerStateNotifierProvider.notifier);
          if (isPlaying) {
            player.pause();
          } else {
            player.resume();
          }
        },
        child: Icon(
          isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
          size: 35,
        ));
  }

  void _navigate2PlayerPage(BuildContext context, Track? track) {
    if (track == null) return;
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (context, _, __) => const Player(),
      transitionDuration: const Duration(milliseconds: 100),
      reverseTransitionDuration: const Duration(milliseconds: 100),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(animation),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
    ));
  }
}
