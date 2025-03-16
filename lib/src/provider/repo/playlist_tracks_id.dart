import 'package:flutter/foundation.dart';
import 'package:listen2/src/ref_extensions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'playlist_tracks_id.g.dart';

@Riverpod(keepAlive: true)
class PlaylistIdsNotifier extends _$PlaylistIdsNotifier {
  static const _keySuffix = 'playlistTracksId';
  String _key = '';

  @override
  Future<List<String>> build(String playlistName) async {
    _key = playlistName + _keySuffix;
    var subscription = ref.storage.value.watch(key: _key).listen((e) {
      load();
    });
    ref.onDispose(() {
      subscription.cancel();
    });
    return await get();
  }

  Future<List<String>> get() async {
    var tracksId =
        ref.storage.value.get(_key, defaultValue: List<String>.empty());
    debugPrint(tracksId.toString());
    if (tracksId == null || (tracksId as List<String>).isEmpty) {
      tracksId = List<String>.empty();
    }
    return tracksId;
  }

  Future set(List<String> ids) async {
    await ref.storage.value.put(_key, ids);
  }

  load() async {
    state = AsyncData(await get());
  }

  add(String id) async {
    var previousState = await future;
    if (previousState.contains(id)) return;

    List<String> added = List.from(previousState);
    added.add(id);
    await set(added);

    return true;
  }

  delete(String id) async {
    var previousState = await future;
    if (!previousState.contains(id)) return;

    List<String> deleted = List.from(previousState);
    deleted.remove(id);
    await set(deleted);

    return true;
  }

  toggle(String id) async {
    var ids = await future;
    debugPrint('toggle track');
    if (ids.contains(id)) {
      await delete(id);
    } else {
      add(id);
    }
  }
}
