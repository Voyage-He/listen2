import 'package:flutter/cupertino.dart';
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
    var res = await _client.getAudioStream(track.bvid);
    
    var s = res.stream;
    List<int> bytesList = [];
    await for (var chunk in s) {
      bytesList.addAll(chunk);
    }

    return Uint8List.fromList(bytesList);
  }

  Future<Track> getTrackbyId(String id) async {
    var res = await _client.getVideoInfo(id);
    print('from favo ${res[3]}');
    return Track(res[0], res[1], res[2], res[3]);
  }
  
  Future<Uint8List> getCover(Track track) async {
    try {
      final bytes = await Globals.storage.temp.read('${track.bvid}/cover');
      print('from local');
      return bytes;
    }
    catch (err) {
      // -网络请求-并且存储本地
      final bytes = await http.readBytes(Uri.parse(track.pictureUrl));
      await Globals.storage.temp.write('${track.bvid}/cover', bytes);
      print('from web');
      return bytes;
    }
  }
}