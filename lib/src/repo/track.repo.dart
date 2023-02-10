import 'package:flutter/foundation.dart';
import 'package:music_api/music_api.dart';

var trackRepo = TrackRepository();

class Track {
  String bvid;
  String title;
  String singer;
  String pictureUrl;
  //  TODO platform

  Track(this.bvid, this.title, this.singer, this.pictureUrl);
}

class TrackRepository {
  final client = BilibiliClient();

  Future<List<Track>> search(keyword) async  {
    if (!trackRepo.client.hasCookie) return [];

    var a = await client.search(keyword);
    print('from search ${a[0].pic}');
    return a.map((bilibiliVideo) => Track(bilibiliVideo.bvid, bilibiliVideo.title, bilibiliVideo.author, 'https:${bilibiliVideo.pic}')).toList();
  }

  Future<Uint8List> getBytes(Track track) async {
    var res = await client.getAudioStream(track.bvid);
    
    var s = res.stream;
    List<int> bytesList = [];
    await for (var chunk in s) {
      bytesList.addAll(chunk);
    }

    return Uint8List.fromList(bytesList);
  }

  Future<Track> getTrackbyId(String id) async {
    var res = await client.getVideoInfo(id);
    print('from favo ${res[3]}');
    return Track(res[0], res[1], res[2], res[3]);
  }
}