import 'package:flutter/foundation.dart';
import 'package:listen2/src/ref_extensions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'playlist_names.g.dart';

@Riverpod(keepAlive: true)
class PlaylistNames extends _$PlaylistNames {
  static const _key = 'playlistNames';

  @override
  Future<List<String>> build() async {
    var subscription = ref.storage.value.watch(key: _key).listen((e) {
      load();
    });
    ref.onDispose(() {
      subscription.cancel();
    });
    return await get();
  }

  Future<List<String>> get() async {
    var playlistNames =
        ref.storage.value.get(_key, defaultValue: List<String>.empty());
    debugPrint(playlistNames.toString());
    if (playlistNames == null || (playlistNames as List<String>).isEmpty) {
      playlistNames = ['favorite'];
    }
    return playlistNames;
  }

  Future set(List<String> names) async {
    await ref.storage.value.put(_key, names);
  }

  load() async {
    state = AsyncData(await get());
  }

  add(String playlistName) async {
    var previousState = await future;
    if (previousState.contains(playlistName)) return;
    List<String> added = List.from(previousState);
    added.add(playlistName);
    await set(added);

    return true;
  }

  delete(String playlistName) async {
    var previousState = await future;
    if (!previousState.contains(playlistName)) return;
    List<String> deleted = List.from(previousState);
    deleted.remove(playlistName);
    await set(deleted);

    return true;
  }

  toggle(String playlistName) async {
    var names = await future;
    debugPrint('toggle playlist');
    if (names.contains(playlistName)) {
      await delete(playlistName);
    } else {
      add(playlistName);
    }
  }
}
