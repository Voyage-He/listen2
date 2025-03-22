import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:listen2/src/provider/global/current_playlist.dart';
import 'package:listen2/src/provider/repo/track.dart';
import 'package:path/path.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path_provider/path_provider.dart';

part 'storage.g.dart';

class Storage {
  // global settings
  Box setting;

  // simple key-value data
  Box value;

  // storage binary data
  Box<Uint8List> binary;

  // TODO manage other custom Box for provider to use
  Map<String, Box> custom;

  Storage(this.setting, this.value, this.binary, this.custom);
}

@Riverpod(keepAlive: true)
Future<Storage> hiveStorage(HiveStorageRef ref) async {
  final docDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(join(docDir.path, 'listen2'));
  Hive.registerAdapter(TrackAdapter());
  Hive.registerAdapter(CurrentPlaylistStateAdapter());

  var setting = await Hive.openBox('setting');
  var value = await Hive.openBox('value');
  var binary = await Hive.openBox<Uint8List>('binary');
  debugPrint("info: HiveStorage initialized");

  if (kDebugMode) {
    // create a item to debug favorite page
    var fs = value.get('favorites');

    if (fs == null || (fs as List).isEmpty) {
      value.put('favorites', ['1aE411n7wb']);
    }
  }

  final currentPlaylistStateBox = await Hive.openBox<CurrentPlaylistState>('current_playlist_state');

  return Storage(setting, value, binary, {"current_playlist_state": currentPlaylistStateBox});
}
