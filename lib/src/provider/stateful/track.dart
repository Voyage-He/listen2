import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:listen2/src/provider/global/storage.dart';
import 'package:listen2/src/provider/repo/bilibili.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;

part 'track.g.dart';

@HiveType(typeId: 1)
class Track {
  @HiveField(0)
  String bvid;
  @HiveField(1)
  String title;
  @HiveField(2)
  String singer;
  @HiveField(3)
  String pictureUrl;
  //  TODO platform

  Track(this.bvid, this.title, this.singer, this.pictureUrl);

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    return other is Track && bvid == other.bvid;
  }
}

@riverpod
Future<Track> track(TrackRef ref, String id) async {
  // TODO Move cache logic to repository
  var tracksBox = await Hive.openBox<Track>('tracks');
  // tracksBox.clear();
  var track = tracksBox.get(id);

  if (track != null) return track;
  try {
    var res = await (await ref.watch(bilibiliClientNotifierProvider.future))
        .getVideoInfo(id);
    print('from favo ${res[3]}');
    final target = Track(res[0], res[1], res[2], res[3]);

    tracksBox.put(id, target);

    return Track(res[0], res[1], res[2], res[3]);
  } catch (e) {
    return Track(id, "wrong", "wrong", "wrong");
  }
}

// @Riverpod(keepAlive: true)
// class CurrentTrack extends _$CurrentTrack {
//   @override
//   Track? build() {
//     return null;
//   }

//   update(Track track) {
//     state = track;
//   }
// }

@riverpod
Future<Uint8List> trackBytes(TrackBytesRef ref, Track track) async {
  var storage = await ref.watch(hiveStorageProvider.future);
  var trackbytes = storage.binary.get(track.bvid);

  if (trackbytes != null) return trackbytes;

  var client = await ref.watch(bilibiliClientNotifierProvider.future);
  final res = await client.getAudioStream(track.bvid);

  // prepare for audio plugin that support stream feature in the future
  List<int> bytesList = [];
  await for (var chunk in res) {
    bytesList.addAll(chunk);
  }
  final bytes = Uint8List.fromList(bytesList);

  storage.binary.put(track.bvid, bytes);

  return bytes;
}

@riverpod
Future<Uint8List> trackCover(TrackCoverRef ref, Track track) async {
  final bytes = await http.readBytes(Uri.parse(track.pictureUrl));
  return bytes;
}
