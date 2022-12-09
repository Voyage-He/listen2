import 'package:audioplayers/audioplayers.dart' as ad;
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

    return Container(
      padding: const EdgeInsets.only(top: 30.0),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [ 
          const Player(),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Input(onChange: (text) {
                  ref.read(keywordProvd.notifier).state = text;
                })
              ),
              Button(
                onTap:() => ref.read(searchResultProvd.notifier).search(),
                child: const Text("search", style: TextStyle(fontSize: 20),)
              )
            ],
          ),
          const Divider(height: 30,),
          Expanded(
            child: Consumer(builder: (context, ref, child) {
              final tracks = ref.watch(searchResultProvd);
              return ListView.builder(
                itemCount: tracks.length,
                itemBuilder:(context, i) {
                  final track = tracks[i];
                  return GestureDetector(
                    onTap: () {
                      print('Tap search item');
                      ref.read(playerStateProvider.notifier).playTrack(track);
                    },
                    child:Row(
                      children: [
                        Image.network(
                          'https:${track.pictureUrl}',
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

class Player extends ConsumerWidget {
  const Player({super.key});

  
  @override
  Widget build(context, ref) {
    final playerState = ref.watch(playerStateProvider);
    final isPlaying = playerState.state == ad.PlayerState.playing;
    final track = playerState.currentTrack;
    return Container(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        children: [
          Column(
            children: [
              Button(
                onTap: (){
                  if (isPlaying) {player.pause();}
                  else {player.resume();}
                },
                circle: true,
                child: Text(
                  isPlaying ? '||' : '|>',
                  style: const TextStyle(fontSize: 20)
                ),
                
              ),
              Button(
                onTap: () {
                  player.stop();
                },
                circle: true,
                child: const Text('口', style: TextStyle(fontSize: 20)),
                
              )
            ],
          ),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track?.title ?? '', style: const TextStyle(fontSize: 20),overflow: TextOverflow.clip,),
                Text(track?.singer ?? '', style: const TextStyle(fontSize: 10),)
              ],
            )
          )
        ],
      ),
    );
  }
}