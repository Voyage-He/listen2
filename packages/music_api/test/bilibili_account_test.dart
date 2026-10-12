import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_api/music_api.dart';
import 'package:requests/requests.dart';

class _Store implements BilibiliSessionStore {
  String? value;
  Object? writeError;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String session) async {
    if (writeError != null) throw writeError!;
    value = session;
  }

  @override
  Future<void> delete() async => value = null;
}

http.Response _json(Object body, {Map<String, String>? headers}) =>
    http.Response(jsonEncode(body), 200, headers: {
      'content-type': 'application/json; charset=utf-8',
      ...?headers
    });

http.Response _nav({bool loggedIn = true}) => _json({
      'code': loggedIn ? 0 : -101,
      'data': {'isLogin': loggedIn, 'mid': 123, 'uname': '测试用户'},
    });

http.Response _poll(int status, {bool cookies = true}) => _json({
      'code': 0,
      'data': {'code': status, 'refresh_token': 'test-refresh-token'},
    },
        headers: !cookies
            ? null
            : {
                'set-cookie':
                    'SESSDATA=test%2Fsession; Path=/; Expires=Wed, 01 Jan 2031 00:00:00 GMT; HttpOnly; Secure,'
                        'bili_jct=test-csrf; Path=/; Expires=Wed, 01 Jan 2031 00:00:00 GMT,'
                        'DedeUserID=123; Path=/; Expires=Wed, 01 Jan 2031 00:00:00 GMT',
              });

String _session({int? expiry}) => jsonEncode({
      'version': 1,
      'cookies': {
        'SESSDATA': 'test%2Fsession',
        'bili_jct': 'test-csrf',
        'DedeUserID': '123'
      },
      'expiresAt': expiry ?? DateTime(2031).millisecondsSinceEpoch,
      'refreshToken': 'test-refresh-token',
    });

void main() {
  late _Store store;
  setUp(() => store = _Store());

  test(
      'QR states do not save credentials until confirmation and nav validation',
      () async {
    var status = 86101;
    final calls = <http.Request>[];
    final client =
        BilibiliAccountClient(store, httpClient: MockClient((request) async {
      calls.add(request);
      if (request.url.path.endsWith('/generate')) {
        return _json({
          'code': 0,
          'data': {
            'url': 'https://account.bilibili.com/scan?key=test',
            'qrcode_key': 'test-key'
          },
        });
      }
      if (request.url.path.endsWith('/nav')) return _nav();
      expect(request.url.queryParameters['qrcode_key'], 'test-key');
      return _poll(status);
    }));
    addTearDown(client.close);
    final qr = await client.generateQrCode();
    expect(qr.key, 'test-key');
    expect(Uri.parse(qr.url).host, 'account.bilibili.com');
    expect(await client.pollQrCode(qr.key), BilibiliQrStatus.waiting);
    status = 86090;
    expect(await client.pollQrCode(qr.key), BilibiliQrStatus.scanned);
    status = 86038;
    expect(await client.pollQrCode(qr.key), BilibiliQrStatus.expired);
    expect(store.value, isNull);
    status = 0;
    expect(await client.pollQrCode(qr.key), BilibiliQrStatus.confirmed);
    expect(client.user!.name, '测试用户');
    expect(client.cookieHeader, contains('SESSDATA=test%2Fsession'));
    final stored = jsonDecode(store.value!);
    expect(stored['refreshToken'], 'test-refresh-token');
    expect(stored['cookies']['bili_jct'], 'test-csrf');
    expect(calls.last.headers['cookie'], contains('bili_jct=test-csrf'));
    expect(
        calls
            .where((r) => !r.url.path.endsWith('/nav'))
            .every((r) => !r.headers.containsKey('cookie')),
        isTrue);
    expect(
        (await Requests.getStoredCookies('passport.bilibili.com'))
            .containsKey('SESSDATA'),
        isFalse);
    expect(
        (await Requests.getStoredCookies('api.bilibili.com'))
            .containsKey('SESSDATA'),
        isFalse);

    final restarted =
        BilibiliAccountClient(store, httpClient: MockClient((request) async {
      expect(request.headers['cookie'], contains('SESSDATA=test%2Fsession'));
      return _nav();
    }));
    addTearDown(restarted.close);
    expect((await restarted.getLoggedInUser())!.mid, 123);
  });

  test(
      'missing cookies, invalid profile and failed secure storage cannot log in',
      () async {
    for (final scenario in ['missing', 'invalid-profile', 'storage']) {
      final client =
          BilibiliAccountClient(store, httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/nav')) {
          return _nav(loggedIn: scenario != 'invalid-profile');
        }
        return _poll(0, cookies: scenario != 'missing');
      }));
      addTearDown(client.close);
      if (scenario == 'storage') {
        store.writeError = StateError('storage unavailable');
      }
      await expectLater(client.pollQrCode('key'),
          scenario == 'storage' ? throwsStateError : throwsFormatException);
      expect(store.value, isNull);
      expect(client.hasSession, isFalse);
      expect(client.user, isNull);
    }
  });

  test('canceling a QR flow rejects an in-flight successful poll', () async {
    final pending = Completer<http.Response>();
    final client = BilibiliAccountClient(store,
        httpClient: MockClient((_) => pending.future));
    addTearDown(client.close);
    final result = client.pollQrCode('key');
    client.cancelQrLogin();
    pending.complete(_poll(0));
    expect(await result, BilibiliQrStatus.expired);
    expect(store.value, isNull);
    expect(client.hasSession, isFalse);
  });

  test('malformed, expired and unsafe sessions are removed', () async {
    for (final value in [
      '{bad',
      _session(expiry: 0),
      jsonEncode({
        'version': 1,
        'cookies': {
          'SESSDATA': 'bad; injected',
          'bili_jct': 'csrf',
          'DedeUserID': '123'
        },
        'expiresAt': DateTime(2031).millisecondsSinceEpoch,
      })
    ]) {
      store.value = value;
      final client = BilibiliAccountClient(store);
      await client.restoreSession();
      expect(store.value, isNull);
      expect(client.hasSession, isFalse);
      client.close();
    }
  });

  test(
      'offline status check preserves credentials; expired identity clears them',
      () async {
    store.value = _session();
    var offline = true;
    final client =
        BilibiliAccountClient(store, httpClient: MockClient((_) async {
      if (offline) throw http.ClientException('offline');
      return _nav(loggedIn: false);
    }));
    addTearDown(client.close);
    await expectLater(
        client.getLoggedInUser(), throwsA(isA<http.ClientException>()));
    expect(store.value, isNotNull);
    offline = false;
    expect(await client.getLoggedInUser(), isNull);
    expect(store.value, isNull);
  });

  test('favorite APIs use account mid, avid, full folder id and encoded CSRF',
      () async {
    store.value = _session();
    final calls = <http.Request>[];
    final client =
        BilibiliAccountClient(store, httpClient: MockClient((request) async {
      calls.add(request);
      expect(request.headers['cookie'], contains('SESSDATA=test%2Fsession'));
      switch (request.url.path) {
        case '/x/web-interface/nav':
          return _nav();
        case '/x/web-interface/view':
          expect(request.url.queryParameters['bvid'], 'BV1abc');
          return _json({
            'code': 0,
            'data': {'aid': 456}
          });
        case '/x/v3/fav/folder/created/list-all':
          expect(request.url.queryParameters,
              {'up_mid': '123', 'type': '2', 'rid': '456'});
          return _json({
            'code': 0,
            'data': {
              'list': [
                {
                  'id': 987123,
                  'fid': 9871,
                  'title': '私密收藏',
                  'attr': 3,
                  'fav_state': 1,
                  'media_count': 4
                },
              ]
            }
          });
        default:
          return _json({'code': 0});
      }
    }));
    addTearDown(client.close);
    final avid = await client.getVideoAid('1abc');
    final folders = await client.getFavoriteFolders(avid: avid);
    expect(folders.single.id, 987123);
    expect(folders.single.isPrivate, isTrue);
    expect(folders.single.containsVideo, isTrue);
    await client.setFavorite(avid, folders.single.id, saved: true);
    expect(calls.last.method, 'POST');
    expect(calls.last.bodyFields, {
      'rid': '456',
      'type': '2',
      'add_media_ids': '987123',
      'del_media_ids': '',
      'csrf': 'test-csrf',
      'platform': 'web'
    });
    await client.setFavorite(avid, folders.single.id, saved: false);
    expect(calls.last.bodyFields['del_media_ids'], '987123');
    expect(calls.last.bodyFields['add_media_ids'], '');
    await client.createFavoriteFolder(' 中文收藏 ', isPrivate: true);
    expect(calls.last.bodyFields,
        {'title': '中文收藏', 'privacy': '1', 'csrf': 'test-csrf'});
  });

  test('authentication rejection clears session and stops later writes',
      () async {
    store.value = _session();
    var writes = 0;
    final client =
        BilibiliAccountClient(store, httpClient: MockClient((_) async {
      writes++;
      return _json({'code': -111});
    }));
    addTearDown(client.close);
    await expectLater(client.setFavorite(456, 789, saved: true),
        throwsA(isA<BilibiliApiException>()));
    expect(store.value, isNull);
    expect(client.hasSession, isFalse);
    await expectLater(client.createFavoriteFolder('new'),
        throwsA(isA<BilibiliApiException>()));
    expect(writes, 1);
  });

  test('logout removes this device credentials even when the network fails',
      () async {
    store.value = _session();
    final client =
        BilibiliAccountClient(store, httpClient: MockClient((request) async {
      expect(request.url.path, '/login/exit/v2');
      expect(request.bodyFields['biliCSRF'], 'test-csrf');
      throw http.ClientException('offline');
    }));
    addTearDown(client.close);
    await expectLater(client.logout(), throwsA(isA<http.ClientException>()));
    expect(store.value, isNull);
    expect(client.cookieHeader, isNull);
  });

  test(
      'private playlist fetch shares the secure session without caching it in Hive',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('bilibili-login-test-');
    final box = await Hive.openBox('account-private', path: directory.path);
    store.value = _session();
    final account =
        BilibiliAccountClient(store, httpClient: MockClient((request) async {
      expect(request.url.path, '/x/v3/fav/resource/list');
      expect(request.headers['cookie'], contains('SESSDATA=test%2Fsession'));
      return _json({
        'code': 0,
        'data': {'medias': [], 'has_more': false}
      });
    }));
    try {
      final client = BilibiliClient(box, account: account);
      expect(await client.getFavoriteList('987123'), isEmpty);
      expect(box.keys, isEmpty);
    } finally {
      account.close();
      await box.close();
      await directory.delete(recursive: true);
    }
  });
}
