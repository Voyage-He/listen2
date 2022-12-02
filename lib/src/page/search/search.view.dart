import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../widget/input/input.dart';
import '../../widget/button/button.dart';

import  './search.logic.dart';
import '../../global/player/player.logic.dart';


class Search extends ConsumerWidget {
  const Search({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var keyword = '';

    return Container(
      padding: const EdgeInsets.only(top: 30.0),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Input(onChange: (text) {
                  keyword = text;
                })
              ),
              Button(
                onTap:() => print(ref.read(searchResultProvd.notifier).search(keyword)),
                child: Text("search", style: TextStyle(fontSize: 20),)
              )
            ],
          ),
          
          Expanded(
            child: Consumer(builder: (context, ref, child) {
              final tracks = ref.watch(searchResultProvd);
              return ListView.builder(
                itemCount: tracks.length,
                itemBuilder:(context, i) {
                  final track = tracks[i];
                  return GestureDetector(
                    onTap: () => ref.read(playerPrvd.notifier).playTrack(track),
                    child:Row(
                      children: [
                        Image.network(
                          'https:' + track.pictureUrl,
                          width: 100,
                          height: 100 / 240 * 135,
                          fit: BoxFit.fill,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(track.title, style: const TextStyle(fontSize: 20),overflow: TextOverflow.ellipsis,),
                              Text(track.singer, style: const TextStyle(fontSize: 10),)
                            ],
                          )
                        )
                      ],
                    )
                  );
                });
            })
          )
        ]
      ),
    );
  }
}

// class searchResult extends ConsumerWidget {

//   @override
//   Widget build() {

//   }
// }