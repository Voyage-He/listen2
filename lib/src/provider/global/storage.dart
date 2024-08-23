import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:listen2/src/provider/stateful/track.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage.g.dart';

class Storage {
  // global settings
  Box setting;

  // simple key-value data
  Box value;

  // storage binary data
  Box<Uint8List> binary;

  // TODO manage other custom Box for provider to use
  // Map<String, Box> custom;

  Storage(this.setting, this.value, this.binary);
}

@Riverpod(keepAlive: true)
Future<Storage> hiveStorage(HiveStorageRef ref) async {
  await Hive.initFlutter();
  Hive.registerAdapter(TrackAdapter());

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

  ref.onDispose(() {
    setting.close();
    value.close();
    binary.close();
    debugPrint("info: HiveStorage closed");
  });
  return Storage(setting, value, binary);
}
