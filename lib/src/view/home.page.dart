import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Colors, Icons, Theme;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:listen2/src/repo/track.repo.dart';

import 'search.page.dart';
import 'favorite.page.dart';
import 'player.page.dart';

import '../bloc/player.cubit.dart';

import './track_cover.widget.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      // decoration: const BoxDecoration(color: Colors.white),
      child: Stack(
        children: [
          const Align(
            alignment: Alignment.topCenter,
            child: Header()
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(5, 40 + 10, 5, 50),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(pageBuilder:(context, _, __) => const FavoratePage(),)
                  );
                },
                child: const Icon(Icons.favorite, color: Colors.redAccent, size: 40,)
              ),
              Text('收藏', style: Theme.of(context).textTheme.headlineSmall)
            ]),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: BottomPlayer(),
          )
        ],
      )
    );
  }
}

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), offset: Offset(0, 7), blurRadius: 10.0, spreadRadius: -5)]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder:(context, _, __) => const Search(),
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
                )
              );
            },
            child: Icon(Icons.search, size: 30)
          ),
        ]
      )
    );
  }
}

class BottomPlayer extends StatelessWidget {

  const BottomPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final track = context.read<PlayerCubit>().state.currentTrack;
        if (track == null) return;
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder:(context, _, __) => const Player(),
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
          )
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color.fromARGB(80, 0, 0, 0), offset: Offset(0, 0), blurRadius: 10.0, spreadRadius: 0.0)]
        ),
        child: Row(
          children: [
            BlocSelector<PlayerCubit, PlayerState, Track?>(
              selector: (state) => state.currentTrack,
              builder: (context, track) {
                return track != null ? TrackCover(track, width: 50, height: 50,) : Container(width: 50, height: 50, color: Colors.grey,);
              }
            ),
            BlocSelector<PlayerCubit, PlayerState, Track?>(
              selector: (state) => state.currentTrack,
              builder: (context, track) {
                return Expanded(child: 
                  Text(
                    track?.title ?? '', 
                    style: const TextStyle(fontSize: 20, overflow: TextOverflow.ellipsis))
                );
              },
            ),
            BlocSelector<PlayerCubit, PlayerState, ap.PlayerState>(
              selector: (state) {
                return state.state;
              },
              builder: (context, state) {
                final isPlaying = state == ap.PlayerState.playing;
                return GestureDetector(
                  onTap: () {
                    final player = context.read<PlayerCubit>();
                    if (isPlaying) {player.pause();}
                    else {player.resume();}
                  },
                  child: Icon(isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 35,)
                );
              },
            ),
            const Icon(Icons.list, size: 40,),
          ],
        ),
      ),
    );
  }
}