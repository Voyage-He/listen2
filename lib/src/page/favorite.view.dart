import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/favorite.cubit.dart';
import '../bloc/player.cubit.dart';
import '../repo/track.repo.dart';

class FavoratePage extends StatelessWidget {
  const FavoratePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 收藏bvid（甚至track完整信息）的本地存储，以及收藏页面列表展示
    return BlocBuilder<FavoriteCubit, List<String>>(
      builder: (context, state) {
        return Container(
            color: Colors.white,
            child: ListView.separated(
              separatorBuilder: (context, index) => const Divider(color: Colors.black,),
              itemCount: state.length,
              itemBuilder: (context, index) {
                return FavoriteTrack(index, state[index]);
              }
            )
          );
      }
    );
  }
}

class FavoriteTrack extends StatelessWidget {
  final int index;
  final String id;

  const FavoriteTrack(this.index, this.id,{
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackCubit, Track?>(
      bloc: TrackCubit(TrackRepo())..getTrackbyId(id), 
      builder: (context, state) {
        const st = TextStyle(fontSize: 15);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (state != null) context.read<PlayerCubit>().playTrack(state);
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(margin: EdgeInsets.symmetric(horizontal: 20), child: Text('${(index + 1).toString()}')),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state?.title ?? '', style: st,),
                      Text(state?.singer ?? '', style: st,)
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    context.read<FavoriteCubit>().toggle(id);
                  },
                  child: Icon(Icons.favorite_outlined, color: Colors.redAccent,)
                ),
              ],
            ),
          ),
        );
    });
    
  }
}