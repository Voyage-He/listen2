import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:requests/requests.dart';

/// Login credentials must use a secure store, separate from anonymous cookies.
abstract class BilibiliSessionStore {
  Future<String?> read();
  Future<void> write(String session);
  Future<void> delete();
}

class BilibiliApiException implements Exception {
  const BilibiliApiException(this.code, this.message);
  final int code;
  final String message;
  @override
  String toString() => message;
}

class BilibiliUser {
  const BilibiliUser({required this.mid, required this.name});
  final int mid;
  final String name;
}

class BilibiliQrCode {
  const BilibiliQrCode({required this.url, required this.key});
  final String url;
  final String key;
}

enum BilibiliQrStatus { waiting, scanned, expired, confirmed }

class BilibiliFavoriteFolder {
  const BilibiliFavoriteFolder({
    required this.id,
    required this.title,
    required this.count,
    required this.isPrivate,
    required this.containsVideo,
  });
  factory BilibiliFavoriteFolder.fromJson(Map data) => BilibiliFavoriteFolder(
        id: data['id'] as int,
        title: data['title'] as String,
        count: data['media_count'] as int? ?? 0,
        isPrivate: ((data['attr'] as int? ?? 0) & 1) != 0,
        containsVideo: data['fav_state'] == 1,
      );
  final int id;
  final String title;
  final int count;
  final bool isPrivate;
  final bool containsVideo;
}

/// Web QR login and favorite APIs from bilibili-API-collect/docs/login and fav.
/// Never passes login cookies to Requests' persistent SharedPreferences jar.
class BilibiliAccountClient {
  BilibiliAccountClient(this.store, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();
  final BilibiliSessionStore store;
  final http.Client _http;
  Map<String, String> _cookies = {};
  Future<void>? _restore;
  int _generation = 0;
  BilibiliUser? user;

  bool get hasSession => _cookies.isNotEmpty;
  String? get cookieHeader => hasSession
      ? _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ')
      : null;

  void close() => _http.close();

  Future<void> restoreSession() async {
    try {
      await (_restore ??= _loadSession());
    } catch (_) {
      _restore = null;
      rethrow;
    }
  }

  Future<void> _loadSession() async {
    final stored = await store.read();
    if (stored == null) return;
    try {
      final data = jsonDecode(stored);
      if (data is! Map || data['version'] != 1 || data['cookies'] is! Map) {
        throw const FormatException();
      }
      final cookies = Map<String, String>.from(data['cookies']);
      _validateCookies(cookies);
      final expiry = data['expiresAt'];
      if (expiry is! int || expiry <= DateTime.now().millisecondsSinceEpoch) {
        throw const FormatException();
      }
      _cookies = cookies;
    } on FormatException {
      await store.delete();
    } on TypeError {
      await store.delete();
    }
  }

  static void _validateCookies(Map<String, String> cookies) {
    for (final key in ['SESSDATA', 'bili_jct', 'DedeUserID']) {
      if (cookies[key]?.isNotEmpty != true) throw const FormatException();
    }
    for (final entry in cookies.entries) {
      if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(entry.key) ||
          RegExp(r'[\x00-\x20\x7f;]').hasMatch(entry.value)) {
        throw const FormatException();
      }
    }
    if (int.tryParse(cookies['DedeUserID']!) == null ||
        int.parse(cookies['DedeUserID']!) <= 0) {
      throw const FormatException();
    }
  }

  Future<http.Response> _request(String host, String path,
      {Map<String, String>? query,
      Map<String, String>? form,
      bool authenticated = true}) async {
    if (authenticated) await restoreSession();
    final headers = <String, String>{
      'User-Agent': 'Mozilla/5.0',
      'Referer': 'https://www.bilibili.com/',
      if (authenticated && cookieHeader != null) 'Cookie': cookieHeader!,
    };
    final uri = Uri.https(host, path, query);
    final response = await (form == null
            ? _http.get(uri, headers: headers)
            : _http.post(uri, headers: headers, body: form))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw BilibiliApiException(response.statusCode, 'Bilibili 请求失败，请稍后重试');
    }
    return response;
  }

  Future<Map> _body(http.Response response) async {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map || data['code'] is! int) {
      throw const FormatException('Bilibili 返回了无效数据');
    }
    final code = data['code'] as int;
    if (code == -101 || code == -111) {
      await clearSession();
      throw const BilibiliApiException(-101, '登录已失效，请重新扫码登录');
    }
    if (code != 0) {
      throw BilibiliApiException(code, 'Bilibili 操作失败（$code），请稍后重试');
    }
    return data;
  }

  Future<BilibiliQrCode> generateQrCode() async {
    final body = await _body(await _request(
        'passport.bilibili.com', '/x/passport-login/web/qrcode/generate',
        authenticated: false));
    final data = body['data'];
    final uri = Uri.tryParse(data['url'] as String);
    if (uri == null ||
        uri.scheme != 'https' ||
        !const {'passport.bilibili.com', 'account.bilibili.com'}
            .contains(uri.host) ||
        data['qrcode_key'] is! String ||
        (data['qrcode_key'] as String).isEmpty) {
      throw const FormatException('Bilibili 返回了无效二维码');
    }
    return BilibiliQrCode(url: uri.toString(), key: data['qrcode_key']);
  }

  /// Call [cancelQrLogin] when leaving the QR screen to reject late responses.
  void cancelQrLogin() => _generation++;

  Future<BilibiliQrStatus> pollQrCode(String key) async {
    final generation = _generation;
    final response = await _request(
        'passport.bilibili.com', '/x/passport-login/web/qrcode/poll',
        query: {'qrcode_key': key}, authenticated: false);
    final data = (await _body(response))['data'];
    switch (data['code']) {
      case 86101:
        return BilibiliQrStatus.waiting;
      case 86090:
        return BilibiliQrStatus.scanned;
      case 86038:
        return BilibiliQrStatus.expired;
      case 0:
        if (generation != _generation) return BilibiliQrStatus.expired;
        final jar = Requests.extractResponseCookies(response.headers);
        final cookies = <String, String>{};
        DateTime? expiry;
        for (final name in [
          'SESSDATA',
          'bili_jct',
          'DedeUserID',
          'DedeUserID__ckMd5'
        ]) {
          final cookie = jar[name];
          if (cookie == null) continue;
          cookies[name] = cookie.value;
          if (cookie['expires'] != null) {
            final date = parseHttpDate(cookie['expires']!);
            if (expiry == null || date.isBefore(expiry)) expiry = date;
          }
        }
        _validateCookies(cookies);
        if (expiry == null || !expiry.isAfter(DateTime.now())) {
          throw const FormatException('登录凭据缺失或已过期，请重新扫码');
        }
        // Check the identity before saving credentials or reporting success.
        final profile = await _fetchUser(cookies);
        if (profile == null ||
            profile.mid.toString() != cookies['DedeUserID']) {
          throw const FormatException('登录状态校验失败，请重新扫码');
        }
        if (generation != _generation) return BilibiliQrStatus.expired;
        await store.write(jsonEncode({
          'version': 1,
          'cookies': cookies,
          'expiresAt': expiry.millisecondsSinceEpoch,
          'refreshToken': data['refresh_token'] as String? ?? '',
        }));
        if (generation != _generation) {
          await store.delete();
          return BilibiliQrStatus.expired;
        }
        _cookies = cookies;
        user = profile;
        _restore = Future.value();
        return BilibiliQrStatus.confirmed;
      default:
        throw const FormatException('未知扫码状态，请刷新二维码');
    }
  }

  Future<BilibiliUser?> _fetchUser(Map<String, String> cookies) async {
    final response = await _http
        .get(Uri.https('api.bilibili.com', '/x/web-interface/nav'), headers: {
      'User-Agent': 'Mozilla/5.0',
      'Referer': 'https://www.bilibili.com/',
      'Cookie': cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
    }).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw const BilibiliApiException(-1, '无法检查登录状态，请检查网络后重试');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body['code'] == -101 || body['data']?['isLogin'] == false) return null;
    if (body['code'] != 0 || body['data']?['isLogin'] != true) {
      throw const FormatException('无法检查 Bilibili 登录状态');
    }
    return BilibiliUser(mid: body['data']['mid'], name: body['data']['uname']);
  }

  Future<BilibiliUser?> getLoggedInUser() async {
    await restoreSession();
    if (!hasSession) return null;
    final profile = await _fetchUser(_cookies);
    if (profile == null) {
      await clearSession();
    } else {
      user = profile;
    }
    return profile;
  }

  Future<void> clearSession() async {
    cancelQrLogin();
    _cookies = {};
    user = null;
    await store.delete();
    _restore = Future.value();
  }

  Future<void> logout() async {
    try {
      await restoreSession();
      if (hasSession) {
        // Always clear this device even when the server is unreachable.
        await _body(await _request('passport.bilibili.com', '/login/exit/v2',
            form: {'biliCSRF': _cookies['bili_jct']!}));
      }
    } finally {
      await clearSession();
    }
  }

  Future<List<BilibiliFavoriteFolder>> getFavoriteFolders({int? avid}) async {
    final profile = user ?? await getLoggedInUser();
    if (profile == null) throw const BilibiliApiException(-101, '请先扫码登录');
    final body = await _body(await _request(
        'api.bilibili.com', '/x/v3/fav/folder/created/list-all',
        query: {
          'up_mid': '${profile.mid}',
          'type': '2',
          if (avid != null) 'rid': '$avid',
        }));
    final folders = body['data']?['list'] ?? [];
    if (folders is! List) throw const FormatException('收藏夹数据无效');
    return folders
        .map((e) => BilibiliFavoriteFolder.fromJson(e as Map))
        .toList();
  }

  Future<int> getVideoAid(String bvid) async {
    final fullId = bvid.startsWith('BV') ? bvid : 'BV$bvid';
    if (!RegExp(r'^BV[0-9A-Za-z]+$').hasMatch(fullId)) {
      throw const FormatException('无效的视频 ID');
    }
    final body = await _body(await _request(
        'api.bilibili.com', '/x/web-interface/view',
        query: {'bvid': fullId}));
    return body['data']['aid'] as int;
  }

  Future<http.Response> getFavoritePage(String mediaId, int page) =>
      _request('api.bilibili.com', '/x/v3/fav/resource/list',
          query: {'media_id': mediaId, 'ps': '20', 'pn': '$page'});

  Future<void> _requireSession() async {
    await restoreSession();
    if (!hasSession) throw const BilibiliApiException(-101, '请先扫码登录');
  }

  Future<void> createFavoriteFolder(String title,
      {bool isPrivate = true}) async {
    if (title.trim().isEmpty) throw const FormatException('请输入收藏夹名称');
    await _requireSession();
    await _body(
        await _request('api.bilibili.com', '/x/v3/fav/folder/add', form: {
      'title': title.trim(),
      'privacy': isPrivate ? '1' : '0',
      'csrf': _cookies['bili_jct']!,
    }));
  }

  Future<void> setFavorite(int avid, int folderId,
      {required bool saved}) async {
    if (avid <= 0 || folderId <= 0) throw const FormatException('无效的收藏参数');
    await _requireSession();
    await _body(
        await _request('api.bilibili.com', '/x/v3/fav/resource/deal', form: {
      'rid': '$avid',
      'type': '2',
      'add_media_ids': saved ? '$folderId' : '',
      'del_media_ids': saved ? '' : '$folderId',
      'csrf': _cookies['bili_jct']!,
      'platform': 'web',
    }));
  }
}
