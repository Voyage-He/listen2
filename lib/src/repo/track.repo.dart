import 'package:flutter/foundation.dart';
import 'package:music_api/music_api.dart';
import 'package:http/http.dart' as http;

import 'package:listen2/src/global/main.dart';

class Track {
  String bvid;
  String title;
  String singer;
  String pictureUrl;
  //  TODO platform

  Track(this.bvid, this.title, this.singer, this.pictureUrl);
}

class TrackRepo {
  final _client = BilibiliClient();

  static final TrackRepo _instance = TrackRepo._internal();
  TrackRepo._internal();
  factory TrackRepo() => _instance;

  Future<void> init() async => await _client.init();

  Future<List<Track>> search(keyword) async  {
    if (!_client.hasCookie) return [];

    var a = await _client.search(keyword);
    print('from search ${a[0].pic}');
    return a.map((bilibiliVideo) => Track(bilibiliVideo.bvid, bilibiliVideo.title, bilibiliVideo.author, 'https:${bilibiliVideo.pic}')).toList();
  }

  Future<Uint8List> getBytes(Track track) async {
    try {
      return await Globals.storage.temp.read('${track.bvid}/media');
    }
    catch (err) {
      final res = await _client.getAudioStream(track.bvid);

      // maybe for buffer feature in the future
      List<int> bytesList = [];
      await for (var chunk in res) {
        bytesList.addAll(chunk);
      }
      final bytes = Uint8List.fromList(bytesList);

      await Globals.storage.temp.write('${track.bvid}/media', bytes);

      return bytes;
    }
    
  }

  Future<Track> getTrackbyId(String id) async {
    var res = await _client.getVideoInfo(id);
    print('from favo ${res[3]}');
    return Track(res[0], res[1], res[2], res[3]);
  }
  
  Future<Uint8List> getCover(Track track) async {
    try {
      final bytes = await Globals.storage.temp.read('${track.bvid}/cover');
      return bytes;
    }
    catch (err) {
      final bytes = await http.readBytes(Uri.parse(track.pictureUrl));
      await Globals.storage.temp.write('${track.bvid}/cover', bytes);
      return bytes;
    }
  }
}