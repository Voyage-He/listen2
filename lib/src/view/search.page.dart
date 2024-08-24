import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/repo/bilibili.dart';
import 'package:listen2/src/provider/stateful/favorite.dart';
import 'package:listen2/src/provider/stateful/track.dart';

import 'package:listen2/src/widget/input/input.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search.page.g.dart';

@riverpod
class KeywordNotifier extends _$KeywordNotifier {
  @override
  String build() {
    return '';
  }

  update(String value) {
    print('update:$value');
    state = value;
  }
}

@riverpod
class SearchResult extends _$SearchResult {
  @override
  Future<List<Track>> build() async {
    return [];
  }

  Future search() async {
    print('call search');
    var client = ref.watch(bilibiliClientNotifierProvider).requireValue;
    if (!client.hasCookie) return [];

    var keyword = ref.read(keywordNotifierProvider);
    print(keyword);
    if (keyword.isEmpty) return [];

    var res = await client.search(keyword);
    var tracks = res
        .map((bilibiliVideo) => Track(bilibiliVideo.bvid, bilibiliVideo.title,
            bilibiliVideo.author, 'https:${bilibiliVideo.pic}'))
        .toList();
    print(tracks[0].bvid);
    state = AsyncData(tracks);
  }
}

@riverpod
Future<Map<String, dynamic>> tracksAndIsFavirite(
    TracksAndIsFaviriteRef ref) async {
  var tracks = await ref.watch(searchResultProvider.future);
  var favo = await ref.watch(favoriteIdsNotifierProvider.future);
  var isFavorite =
      List.generate(tracks.length, (i) => favo.contains(tracks[i].bvid));
  return {'tracks': tracks, 'isFavorite': isFavorite};
}

class Search extends ConsumerWidget {
  const Search({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(keywordNotifierProvider);
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
          children: [const Header(), Expanded(child: _searchResult(ref))]),
    );
  }

  Widget _searchResult(WidgetRef ref) {
    var tracksWithIsFavoraite = ref.watch(tracksAndIsFaviriteProvider);
    return tracksWithIsFavoraite.when(
        data: (value) {
          var tracks = value['tracks'];
          var isFavorites = value['isFavorite'];
          return ListView.separated(
              separatorBuilder: (context, index) => const Divider(height: 0),
              itemCount: tracks.length,
              itemBuilder: (context, i) {
                return _searchItem(ref, tracks[i], isFavorites[i]);
              });
        },
        error: (_, __) => const Text("err"),
        loading: () => const Text("loading"));
  }

  Widget _searchItem(WidgetRef ref, Track track, bool isFavorite) {
    return GestureDetector(
        onTap: () => ref.read(currentTrackProvider.notifier).update(track),
        child: Container(
            padding: const EdgeInsets.symmetric(),
            child: Row(children: [
              // Image.network(
              //   track.pictureUrl,
              //   width: 115,
              //   height: 115 / 240 * 135,
              //   fit: BoxFit.fill,
              // ),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      track.title.length < 30
                          ? track.title
                          : '${track.title.substring(0, 30)}...',
                      style: const TextStyle(
                          fontSize: 15, overflow: TextOverflow.clip)),
                  Text(
                    track.singer,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  )
                ],
              )),
              Container(
                  margin: const EdgeInsets.only(right: 20),
                  child: GestureDetector(
                      onTap: () => ref
                          .read(favoriteIdsNotifierProvider.notifier)
                          .toggle(track.bvid),
                      child: isFavorite
                          ? const Icon(
                              Icons.favorite_outlined,
                              color: Colors.redAccent,
                            )
                          : const Icon(Icons.favorite_border))),
            ])));
  }
}

class Header extends ConsumerWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
        decoration: BoxDecoration(
            color: Color.fromARGB(255, 228, 228, 228),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  offset: Offset(0, 7),
                  blurRadius: 10.0,
                  spreadRadius: -5)
            ]),
        child: Row(children: [
          GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.search, size: 30)),
          Expanded(child: _input(ref)),
          GestureDetector(
              onTap: () => ref.read(searchResultProvider.notifier).search(),
              child: const Icon(Icons.search, size: 30)),
        ]));
  }

  Widget _input(WidgetRef ref) {
    // ref.watch(keywordNotifierProvider);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
      decoration: const BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.all(Radius.circular(10))),
      child: Input(
        onChange: (text) {
          print('change:' + text);
          ref.read(keywordNotifierProvider.notifier).update(text);
        },
        onDone: () => {ref.read(searchResultProvider.notifier).search()},
      ),
    );
  }
}
