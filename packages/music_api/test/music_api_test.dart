import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:music_api/music_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {

  test("1", ()async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('counter', 10);
    final int? counter = prefs.getInt('counter');
    print(counter);
  });

  group("bilibili-client", () {
    late BilibiliClient c;

    setUp(() async {
      c = BilibiliClient();
      await c.init();
    });

    test('get-video-info', () async {
      String bvid = "15G4y1u7sy";
      var res = await c.getVideoInfo(bvid);

      // assert(res.statusCode == 200);
      // print(res.body);
    });

    test('search', () async {
      var res = await c.search("蒸汽进行曲");
      print(res[0]);
    });

    test("getAudioUrl", () async {
      var res = await c.getAudioUrl("1yA4y197qE", 577322836);
      print(res);
    });

    test("getCid", () async  {
      var res = await c.getCid('1yA4y197qE');
      print(res);
    });

    test("getAudio", () async  {
      var audioUrl = 'https://xy121x205x162x59xy.mcdn.bilivideo.cn:4483/upgcxcode/36/28/577322836/577322836_nb2-1-30280.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&uipk=5&nbs=1&deadline=1674571312&gen=playurlv2&os=mcdn&oi=1883493844&trid=0000fb51d70242594790910a424322168cfbu&mid=0&platform=pc&upsig=9793dc3b643fad4455aa92cfe8ca1a7e&uparams=e,uipk,nbs,deadline,gen,os,oi,trid,mid,platform&mcdnid=11000334&bvc=vod&nettype=0&orderid=0,3&buvid=Set-Cookie: buvid3=9A5BF3F2-CA0D-7038-CCA1-DAD3175D6E5268780infoc&build=0&agrr=0&bw=40730&logo=A0000400';
      var res = await c.getAudio(audioUrl);
      var f = File('./res.m4a');
      f.writeAsBytesSync(res.bodyBytes);
    });

    test("getAudioStream", () async  {
      var audioUrl = 'https://xy121x205x162x59xy.mcdn.bilivideo.cn:4483/upgcxcode/36/28/577322836/577322836_nb2-1-30280.m4s?e=ig8euxZM2rNcNbdlhoNvNC8BqJIzNbfqXBvEqxTEto8BTrNvN0GvT90W5JZMkX_YN0MvXg8gNEV4NC8xNEV4N03eN0B5tZlqNxTEto8BTrNvNeZVuJ10Kj_g2UB02J0mN0B5tZlqNCNEto8BTrNvNC7MTX502C8f2jmMQJ6mqF2fka1mqx6gqj0eN0B599M=&uipk=5&nbs=1&deadline=1674571312&gen=playurlv2&os=mcdn&oi=1883493844&trid=0000fb51d70242594790910a424322168cfbu&mid=0&platform=pc&upsig=9793dc3b643fad4455aa92cfe8ca1a7e&uparams=e,uipk,nbs,deadline,gen,os,oi,trid,mid,platform&mcdnid=11000334&bvc=vod&nettype=0&orderid=0,3&buvid=Set-Cookie: buvid3=9A5BF3F2-CA0D-7038-CCA1-DAD3175D6E5268780infoc&build=0&agrr=0&bw=40730&logo=A0000400';
      var res = await c.getAudioStream(audioUrl);
      await for (var b in res) {
        print(String.fromCharCodes(b));
      }
    });
  });
}