import 'dart:convert';
import 'bilibili_account.dart';

import 'package:hive/hive.dart';
import 'package:http_parser/http_parser.dart';
import 'package:requests/requests.dart';
import 'package:http/http.dart';
part './bilibili_model.dart';

class BilibiliClient {
  static const _cookieKey = 'bilibili_cookies';
  static const _cookieVersion = 1;
  static const _homepageHost = 'www.bilibili.com';
  static const _apiHost = 'api.bilibili.com';
  bool hasCookie = false; // hasCookie的用处？
  Box box;

  BilibiliClient(this.box, {this.account});
  final BilibiliAccountClient? account;

  Future<void> init() async {
    hasCookie = false;
    final cookies = await getCookiesFromLocal();
    if (cookies != null) {
      print('cookies from -local');
      await setCookie(cookies);
      hasCookie = true;
    } else {
      await refreshCookies();
    }
  }

  Future<void> refreshCookies() async {
    hasCookie = false;
    await box.delete(_cookieKey);
    await Requests.clearStoredCookies(_homepageHost);
    await Requests.clearStoredCookies(_apiHost);
    final cookies = await getCookieFromNet();
    if (cookies.isEmpty) {
      throw StateError('Bilibili did not return any cookies');
    }
    await saveCookiesToLocal(cookies);
    final persisted = await getCookiesFromLocal();
    if (persisted == null) throw StateError('Bilibili cookies are not valid');
    await setCookie(persisted);
    hasCookie = true;
    print('cookies refreshed from net');
  }

  Future<CookieJar?> getCookiesFromLocal() async {
    final stored = box.get(_cookieKey);
    if (stored == null) return null;
    try {
      if (stored is! String) {
        throw const FormatException('Invalid cookie cache');
      }
      final data = jsonDecode(stored);
      if (data is! Map ||
          data['version'] != _cookieVersion ||
          data['cookies'] is! List ||
          (data['cookies'] as List).isEmpty) {
        throw const FormatException('Invalid cookie cache');
      }
      final cookies = CookieJar();
      final now = DateTime.now().toUtc();
      for (final entry in data['cookies']) {
        if (entry is! Map ||
            entry['name'] is! String ||
            entry['value'] is! String ||
            !_validCookie(entry['name'], entry['value'])) {
          throw const FormatException('Invalid cookie entry');
        }
        final cookie = Cookie(entry['name'], entry['value']);
        final expiresAt = entry['expiresAt'];
        if (expiresAt != null) {
          if (expiresAt is! int || expiresAt.abs() > 8640000000000000) {
            throw const FormatException('Invalid expiry');
          }
          final expiry =
              DateTime.fromMillisecondsSinceEpoch(expiresAt, isUtc: true);
          if (!expiry.isAfter(now)) {
            throw const FormatException('Expired cookie');
          }
          cookie['expires'] = formatHttpDate(expiry);
        }
        cookies[cookie.name] = cookie;
      }
      return cookies;
    } on FormatException {
      // Old caches stored Cookie.toString(), which includes "Set-Cookie:".
      // Discard them instead of restoring malformed values into request headers.
      await box.delete(_cookieKey);
      return null;
    }
  }

  Future<void> saveCookiesToLocal(CookieJar cookies) async {
    if (cookies.isEmpty) throw StateError('Cannot persist empty cookies');
    final now = DateTime.now().toUtc();
    final entries = <Map<String, Object?>>[];
    for (final cookie in cookies.values) {
      if (!_validCookie(cookie.name, cookie.value)) {
        throw const FormatException('Invalid cookie value');
      }
      DateTime? expiry;
      final maxAge = cookie['max-age'];
      if (maxAge != null) {
        final seconds = int.tryParse(maxAge);
        if (seconds == null) {
          throw const FormatException('Invalid cookie max-age');
        }
        expiry = now.add(Duration(seconds: seconds));
      } else if (cookie['expires'] != null) {
        expiry = parseHttpDate(cookie['expires']!);
      }
      if (expiry != null && !expiry.isAfter(now)) continue;
      entries.add({
        'name': cookie.name,
        'value': cookie.value,
        'expiresAt': expiry?.millisecondsSinceEpoch,
      });
    }
    if (entries.isEmpty) throw StateError('Cannot persist expired cookies');
    await box.put(
        _cookieKey,
        jsonEncode({
          'version': _cookieVersion,
          'cookies': entries,
        }));
  }

  static bool _validCookie(String name, String value) =>
      RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$").hasMatch(name) &&
      !value.toLowerCase().contains('set-cookie:') &&
      !RegExp(r'[\x00-\x20\x7f;]').hasMatch(value);

  Future<void> setCookie(CookieJar cookies) async {
    await Requests.setStoredCookies(
        Requests.getHostname('https://api.bilibili.com'), cookies);
  }

  Future<CookieJar> getCookieFromNet() async {
    final response = await Requests.get("https://www.bilibili.com",
        persistCookies: false,
        headers: {
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36 Edg/107.0.1418.56"
        });
    if (!response.success) {
      throw StateError(
          'Bilibili cookie refresh failed: HTTP ${response.statusCode}');
    }
    return Requests.extractResponseCookies(response.headers);
  }

  Future<List<BilibiliVideoModel>> search(String keyword) async {
    Response res = await Requests.get(
      'https://api.bilibili.com/x/web-interface/search/type',
      queryParameters: {'keyword': keyword, 'search_type': 'video'},
    );
    if (!res.success) {
      throw StateError('Bilibili search failed: HTTP ${res.statusCode}');
    }
    final body = res.json();
    if (body['code'] != 0) {
      throw StateError(
          'Bilibili search failed: ${body['code']} ${body['message']}');
    }
    final results = body['data']['result'];
    return BilibiliVideoModel.fromList(results ?? []);
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

  Future<Response> getFavoritePage(String mediaId, int page) async {
    await account?.restoreSession();
    if (account?.hasSession == true) {
      return account!.getFavoritePage(mediaId, page);
    }
    return Requests.get(
      'https://api.bilibili.com/x/v3/fav/resource/list',
      queryParameters: {'media_id': mediaId, 'ps': '20', 'pn': '$page'},
      // Auth cookies are held in secure storage, never in Requests' cache.
      persistCookies: false,
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Referer': 'https://www.bilibili.com/',
      },
    );
  }

  /// Reads every page in collection order, using the same API as Subsonic.
  Future<List<BilibiliVideoModel>> getFavoriteList(String mediaId) async {
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(mediaId)) {
      throw const FormatException('Invalid Bilibili favorite ID');
    }
    final videos = <BilibiliVideoModel>[];
    final seen = <String>{};
    for (var page = 1;; page++) {
      final response = await getFavoritePage(mediaId, page);
      if (!response.success) {
        throw StateError(
            'Bilibili favorites failed: HTTP ${response.statusCode}');
      }
      final body = response.json();
      if (body['code'] == -101 || body['code'] == -111) {
        await account?.clearSession();
        throw const BilibiliApiException(-101, '登录已失效，请重新扫码登录');
      }
      if (body['code'] != 0 || body['data'] is! Map) {
        throw StateError('Bilibili favorites failed: ${body['message']}');
      }
      final data = body['data'];
      final medias = data['medias'] ?? [];
      if (medias is! List || data['has_more'] is! bool) {
        throw const FormatException('Invalid Bilibili favorites response');
      }
      for (final media in medias) {
        if (media is! Map ||
            media['bvid'] is! String ||
            !RegExp(r'^BV[0-9A-Za-z]+$').hasMatch(media['bvid'])) {
          continue;
        }
        final video = BilibiliVideoModel.fromFavorite(media);
        if (seen.add(video.bvid)) videos.add(video);
      }
      if (!data['has_more']) return videos;
      if (medias.isEmpty) {
        throw const FormatException('Missing Bilibili favorites page');
      }
    }
  }

  Future<String> getAudioUrl(String bvid, int cid) async {
    // TODO Choose audio clarity.
    Response res = await Requests.get(
      'https://api.bilibili.com/x/player/playurl',
      queryParameters: {'bvid': bvid, 'cid': cid, 'fnval': 16},
    );
    return res.json()['data']['dash']['audio'][0]['baseUrl'];
  }

  Future<int> getCid(String bvid) async {
    Response res = await Requests.get(
      'https://api.bilibili.com/x/player/pagelist',
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
