import 'package:hive/hive.dart';
import 'package:requests/requests.dart';
import 'package:http/http.dart';
part './bilibili_model.dart';

class BilibiliClient {
  bool hasCookie = false; // hasCookie的用处？
  Box value;

  BilibiliClient(this.value);

  Future<void> init() async {
    var cookies = await getCookiesFromLocal();
    if (cookies != null) {
      print('cookies from -local');
      await setCookie(cookies);
    } else {
      var cookies = await getCookieFromNet();
      print('cookies from net');
      await setCookie(cookies);
      saveCookiesToLocal(cookies);
    }
    hasCookie = true;
  }

  Future<CookieJar?> getCookiesFromLocal() async {
    final String? cookiesStr = value.get('bilibili_cookies');

    if (cookiesStr == null) return null;

    var cookies = CookieJar();

    var cookieStrList = cookiesStr.split('?');
    var cookiesMap = <String, Cookie>{};
    for (var cookieStr in cookieStrList) {
      var cookieList = cookieStr.split('!');
      cookiesMap[cookieList[0]] = Cookie(cookieList[0], cookieList[1]);
    }

    cookies.addAll(cookiesMap);
    return cookies;
  }

  Future<void> saveCookiesToLocal(CookieJar cookies) async {
    var str = '';
    cookies.forEach((key, value) {
      if (str.isEmpty) {
        str = '$key!$value';
      } else {
        str = '$str?$key!$value';
      }
    });

    await value.put('bilibili_cookies', str);
  }

  Future<void> setCookie(CookieJar cookies) async {
    await Requests.setStoredCookies(
        Requests.getHostname('https://api.bilibili.com'), cookies);
  }

  Future<CookieJar> getCookieFromNet() async {
    await Requests.get("https://www.bilibili.com", headers: {
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36 Edg/107.0.1418.56"
    });
    return await Requests.getStoredCookies(
        Requests.getHostname("https://www.bilibili.com"));
  }

  Future<List<BilibiliVideoModel>> search(String keyword) async {
    Response res = await Requests.get(
      'http://api.bilibili.com/x/web-interface/search/type',
      queryParameters: {'keyword': keyword, 'search_type': 'video'},
    );
    assert(res.success);
    // var bvid = res.json()['data']['result'][0]['bvid'] as String;
    // print(bvid.split(RegExp(r'BV[\w+]'))[1]);

    return BilibiliVideoModel.fromList(res.json()["data"]['result']);
  }

  Future<List<String>> getVideoInfo(String bvid) async {
    Response res = await Requests.get(
        'https://api.bilibili.com/x/web-interface/view',
        queryParameters: {'bvid': bvid});

    String bvid2 = res.json()['data']['bvid'];
    String title = res.json()['data']['title'];
    String pic = res.json()['data']['pic'];
    String author = res.json()['data']['owner']['name'];

    return [bvid, title, author, pic];
  }

  Future<String> getAudioUrl(String bvid, int cid) async {
    // TODO Choose audio clarity.
    Response res = await Requests.get(
      'http://api.bilibili.com/x/player/playurl',
      queryParameters: {'bvid': bvid, 'cid': cid, 'fnval': 16},
    );
    return res.json()['data']['dash']['audio'][0]['baseUrl'];
  }

  Future<int> getCid(String bvid) async {
    Response res = await Requests.get(
      'http://api.bilibili.com/x/player/pagelist',
      queryParameters: {
        'bvid': bvid,
      },
    );
    print(res.json());
    return res.json()['data'][0]['cid'];
  }

  Future<Response> getAudio(audioUrl) async {
    Response res = await Requests.get(audioUrl,
        headers: {'Referer': 'https://www.bilibili.com'});
    return res;
  }

  Future<Stream> getAudioStream(String bvid) async {
    var cid = await getCid(bvid);
    var audioUrl = await getAudioUrl(bvid, cid);

    var req = Request('GET', Uri.parse(audioUrl));
    req.headers['Referer'] = 'https://www.bilibili.com';
    req.headers['Host'] = Requests.getHostname(audioUrl);
    req.headers['User-Agent'] =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36 Edg/107.0.1418.56';
    return (await Client().send(req)).stream;
  }
}
