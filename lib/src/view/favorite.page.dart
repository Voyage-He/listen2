import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme, Colors, Divider, Icons;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/favorite.cubit.dart';
import '../bloc/player.cubit.dart';
import '../repo/track.repo.dart';

class FavoratePage extends StatelessWidget {
  const FavoratePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 收藏bvid（甚至track完整信息）的本地存储，以及收藏页面列表展示
    return BlocBuilder<FavoriteCubit, List<Track>>(
      builder: (context, state) {
        return Container(
            color: Colors.white,
            child: ListView.separated(
              separatorBuilder: (context, index) => const Divider(color: Colors.black26, height: 1,),
              itemCount: state.length,
              itemBuilder: (context, index) {
                return _favoriteItem(index, state[index]);
              }
            )
          );
      }
    );
  }

  Widget _favoriteItem(int index, Track track) {
    return Builder(
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (track != null) context.read<PlayerCubit>().playTrack(track);
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(margin: const EdgeInsets.symmetric(horizontal: 10), child: Text((index + 1).toString())),
                Expanded(
                  child: _trackInfo(context, track),
                ),
                _dislikeButton(context, track.bvid),
              ],
            ),
          ),
        );
    });
  }

  Widget _trackInfo(BuildContext context, Track? track) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(track?.title ?? '', style: Theme.of(context).textTheme.bodyLarge),
        Text(track?.singer ?? '', style: Theme.of(context).textTheme.bodyMedium)
      ],
    );
  }

  Widget _dislikeButton(BuildContext context, String id) {
    return GestureDetector(
      onTap: () {
        context.read<FavoriteCubit>().toggle(id);
      },
      child: const Icon(Icons.favorite_outlined, color: Colors.redAccent)
    );
  }
}