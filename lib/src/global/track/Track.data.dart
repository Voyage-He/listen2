import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_api/music_api.dart';

var trackRpstr = TrackRepository();

class Track {
  String bvid;
  String title;
  String singer;
  String pictureUrl;
  //  TODO platform?

  Track(this.bvid, this.title, this.singer, this.pictureUrl);
}

class TrackRepository {
  final client = BilibiliClient.init();

  Future<List<Track>> search(keyword) async  {
    var a = await client.search(keyword);
    return a.map((bilibiliVideo) => Track(bilibiliVideo.bvid, bilibiliVideo.title, bilibiliVideo.author, bilibiliVideo.pic)).toList();
  }

  Future<Uint8List> getBytes(Track track) async {
    var cid = await client.getCid(track.bvid);
    var url = await client.getAudioUrl(track.bvid, cid);
    var res = await client.getAudioStream(url);

    int bytesLength  = int.parse(res.headers['content-length']!);
    
    var s = res.stream;
    List<int> bytesList = [];
    await for (var chunk in s) {
      bytesList.addAll(chunk);
    }

    return Uint8List.fromList(bytesList);
  }
}