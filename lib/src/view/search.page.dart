import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:listen2/src/widget/input/input.dart';

import 'package:listen2/src/bloc/favorite.cubit.dart';
import 'package:listen2/src/bloc/player.cubit.dart';
import '../bloc/search.cubit.dart';

import 'package:listen2/src/repo/track.repo.dart';

class Search extends StatelessWidget {
  const Search({super.key});

  @override
  Widget build(BuildContext context) {

    return BlocProvider<SearchCubit>(
      create: (context) => SearchCubit(),
      child: Container(
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            children: [
              const Header(),
              Expanded(
                child: _searchResult()
              )
            ]
          ),
        ),
    );
  }

  Widget _searchResult() {
    return BlocBuilder<SearchCubit, List<Track>>(
      builder: (context, tracks) {
        return BlocBuilder<FavoriteCubit, List<Track>>(
          builder: (context, favorites) {
            return ListView.separated(
              separatorBuilder: (context, index) => const Divider(height: 0),
              itemCount: tracks.length,
              itemBuilder:(context, i) {
                final track = tracks[i];
                return _searchItem(context, track, favorites.contains(track));
              });
          },
        );
      },
    );
  }

  Widget _searchItem(BuildContext context, Track track, bool isFavorite) {
    return GestureDetector(
      onTap: () => context.read<PlayerCubit>().playTrack(track),
      child: Container(
        padding: const EdgeInsets.symmetric(),
        child: Row(
          children: [
            Image.network(
              track.pictureUrl,
              width: 115,
              height: 115 / 240 * 135,
              fit: BoxFit.fill,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title.length < 30 ? track.title : '${track.title.substring(0, 30)}...', style: const TextStyle(fontSize: 15,overflow: TextOverflow.clip)),
                  Text(track.singer, style: const TextStyle(fontSize: 13, color: Colors.grey),)
                ],
              )
            ),
            Container(
              margin: const EdgeInsets.only(right: 20),
              child: GestureDetector(
                onTap: () => context.read<FavoriteCubit>().toggle(track.bvid),
                child: isFavorite ?
                        const Icon(Icons.favorite_outlined, color: Colors.redAccent,) : 
                        const Icon(Icons.favorite_border)
                        
              ),
            )
            
          ],
        ),
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
        children: [
          Expanded(
            child: _input(context)
          ),
          GestureDetector(
            onTap: () => context.read<SearchCubit>().search(),
            child: const Icon(Icons.search, size: 30)
          ),
        ]
      )
    );
  }

  Widget _input(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.all(Radius.circular(10))
      ),
      child: Input(
        onChange: (text) => context.read<SearchCubit>().onKeywordChange(text),
        onDone: () => context.read<SearchCubit>().search(),
      ),
    );
  }
}