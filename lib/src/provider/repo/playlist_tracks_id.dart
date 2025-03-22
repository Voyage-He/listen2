import 'package:flutter/foundation.dart';
import 'package:listen2/src/ref_extensions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'playlist_tracks_id.g.dart';

@Riverpod(keepAlive: true)
class PlaylistIdsNotifier extends _$PlaylistIdsNotifier {
  static const _keySuffix = 'playlistTracksId';
  String _key = '';

  @override
  List<String> build(String playlistName) {
    _key = playlistName + _keySuffix;
    var subscription = ref.storage.value.watch(key: _key).listen((e) {
      load();
    });
    ref.onDispose(() {
      subscription.cancel();
    });
    return get();
  }

  List<String> get() {
    var tracksId =
        ref.storage.value.get(_key, defaultValue: List<String>.empty());
    debugPrint(tracksId.toString());
    if (tracksId == null || (tracksId as List<String>).isEmpty) {
      tracksId = List<String>.empty();
    }
    return tracksId;
  }

  void set(List<String> ids) {
    ref.storage.value.put(_key, ids);
  }

  load() async {
    state = get();
  }

  add(String id) async {
    var previousState = state;
    if (previousState.contains(id)) return;

    List<String> added = List.from(previousState);
    added.add(id);
    set(added);

    return true;
  }

  delete(String id) async {
    var previousState = state;
    if (!previousState.contains(id)) return;

    List<String> deleted = List.from(previousState);
    deleted.remove(id);
    set(deleted);

    return true;
  }

  toggle(String id) async {
    var ids = state;
    debugPrint('toggle track');
    if (ids.contains(id)) {
      await delete(id);
    } else {
      add(id);
    }
  }
}
