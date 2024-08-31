import 'package:flutter/foundation.dart';
import 'package:listen2/src/provider/global/storage.dart';
import 'package:listen2/src/provider/stateful/track.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'favorite.g.dart';

@Riverpod(keepAlive: true)
class FavoriteIdsNotifier extends _$FavoriteIdsNotifier {
  @override
  Future<List<String>> build() async {
    var storage = await ref.watch(hiveStorageProvider.future);
    var subscription = storage.value.watch(key: 'favorites').listen((e) {
      loadFavorites();
    });
    ref.onDispose(() {
      subscription.cancel();
    });
    return await getFavorites();
  }

  Future<List<String>> getFavorites() async {
    var storage = await ref.watch(hiveStorageProvider.future);
    debugPrint(storage.toString());
    var favorites =
        storage.value.get('favorites', defaultValue: List<String>.empty());
    debugPrint(favorites.toString());
    if (favorites == null || (favorites as List<String>).isEmpty) {
      favorites = List<String>.empty();
    }
    return favorites;
  }

  Future setFavorites(List<String> ids) async {
    var storage = await ref.watch(hiveStorageProvider.future);
    await storage.value.put('favorites', ids);
  }

  loadFavorites() async {
    state = AsyncData(await getFavorites());
  }

  add(String id) async {
    var previousState = await future;
    List<String> added = List.from(previousState);
    added.add(id);
    await setFavorites(added);

    return true;
  }

  delete(String id) async {
    var previousState = await future;
    List<String> deleted = List.from(previousState);
    deleted.remove(id);
    await setFavorites(deleted);

    return true;
  }

  toggle(String id) async {
    var ids = await future;
    debugPrint('toggle favo');
    if (ids.contains(id)) {
      await delete(id);
    } else {
      add(id);
    }
  }
}

@Riverpod(keepAlive: true)
class FavoriteTracksNotifier extends _$FavoriteTracksNotifier {
  final _key = 'favoriteTracks';

  @override
  Future<List<Track>> build() async {
    var storage = await ref.watch(hiveStorageProvider.future);
    var subscription = storage.value.watch(key: _key).listen((e) {
      load();
    });
    ref.onDispose(() {
      subscription.cancel();
    });
    return await get();
  }

  Future<List<Track>> get() async {
    var storage = await ref.watch(hiveStorageProvider.future);
    var favorites = storage.value.get(_key, defaultValue: List<Track>.empty());
    debugPrint(favorites.toString());

    favorites ??= List<Track>.empty();
    return favorites;
  }

  Future set(List<Track> track) async {
    var storage = await ref.watch(hiveStorageProvider.future);
    await storage.value.put(_key, track);
  }

  load() async {
    state = AsyncData(await get());
  }

  add(Track track) async {
    var previousState = await future;
    List<Track> added = List.from(previousState);
    added.add(track);
    await set(added);

    return true;
  }

  delete(Track track) async {
    var previousState = await future;
    List<Track> deleted = List.from(previousState);
    deleted.remove(track);
    await set(deleted);

    return true;
  }

  toggle(Track track) async {
    var tracks = await future;
    debugPrint('toggle favo');
    if (tracks.contains(track)) {
      await delete(track);
    } else {
      add(track);
    }
  }
}
