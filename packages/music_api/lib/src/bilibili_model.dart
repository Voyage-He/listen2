part of './bilibili_client.dart';

class BilibiliVideoModel {
  final String title;
  final String bvid;
  final int avid;
  final String author;
  final int mid;
  final String pic;

  BilibiliVideoModel.fromJson(Map<String, dynamic> json)
      : title = (json['title']).replaceAll(RegExp(r'<[^>]*>'), ''),
        bvid = (json['bvid']).split(RegExp('BV'))[1],
        avid = json['aid'],
        author = json['author'],
        mid = json['mid'],
        pic = json['pic'];

  // Map<String, dynamic> toJson() => {
  //   title: title,
  //   bvid: bvid,
  //   avid: avid,
  //   author: author,
  //   mid: mid,
  //   pic: pic,
  // };

  static List<BilibiliVideoModel> fromList(List<dynamic> l) {
    final List<BilibiliVideoModel> videos = [];
    for (var i in l) {
      BilibiliVideoModel video = BilibiliVideoModel.fromJson(i);
      videos.add(video);
    }
    return videos;
  }

  @override
  String toString() {
    return 'title$title,bvid$bvid';
  }
}
