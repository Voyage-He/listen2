import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:music_api/music_api.dart';
import 'package:requests/requests.dart' as requests;

class _Client extends BilibiliClient {
  _Client(super.box);

  int fetches = 0;
  requests.CookieJar fresh = requests.CookieJar()
    ..['probe'] = requests.Cookie('probe', 'fresh-token');
  Object? failure;

  @override
  Future<requests.CookieJar> getCookieFromNet() async {
    fetches++;
    if (failure != null) throw failure!;
    return fresh;
  }
}

void main() {
  late Directory directory;
  late Box box;
  late _Client client;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('listen2-cookie-test-');
    box = await Hive.openBox('cookies', path: directory.path);
    client = _Client(box);
    await _clearRequestCookies();
  });

  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
    await _clearRequestCookies();
  });

  test('raw cookie values survive a disk reopen, including old delimiters',
      () async {
    final cookies = requests.CookieJar()
      ..['probe'] = requests.Cookie('probe', 'test-token!?=encoded');
    await client.saveCookiesToLocal(cookies);
    await box.close();
    box = await Hive.openBox('cookies', path: directory.path);
    client = _Client(box);
    await client.init();
    final restored =
        await requests.Requests.getStoredCookies('api.bilibili.com');
    expect(restored['probe']!.value, 'test-token!?=encoded');
    expect(client.fetches, 0);
    expect(client.hasCookie, isTrue);
  });

  test('old cache refreshes without changing favorites', () async {
    await box.put('favorites', ['BV1aE411n7wb']);
    await box.put('bilibili_cookies', 'probe!Set-Cookie: probe=old-token');
    await client.init();
    expect(client.fetches, 1);
    expect(client.hasCookie, isTrue);
    expect(
        (await client.getCookiesFromLocal())!['probe']!.value, 'fresh-token');
    expect(box.get('favorites'), ['BV1aE411n7wb']);
    expect(jsonDecode(box.get('bilibili_cookies'))['version'], 1);
  });

  test('malformed and unsupported caches are discarded', () async {
    for (final stored in [
      123,
      '',
      '{bad json',
      jsonEncode({'version': 2, 'cookies': []}),
      jsonEncode({'version': 1, 'cookies': []}),
      jsonEncode({
        'version': 1,
        'cookies': [
          {'name': 'probe', 'value': 123}
        ]
      }),
      jsonEncode({
        'version': 1,
        'cookies': [
          {'name': 'probe', 'value': 'Set-Cookie: probe=x'}
        ]
      }),
      jsonEncode({
        'version': 1,
        'cookies': [
          {'name': 'probe', 'value': 'x', 'expiresAt': 999999999999999999}
        ]
      }),
    ]) {
      await box.put('bilibili_cookies', stored);
      expect(await client.getCookiesFromLocal(), isNull);
      expect(box.containsKey('bilibili_cookies'), isFalse);
    }
  });

  test('expires and max-age survive persistence with max-age taking precedence',
      () async {
    final cookie = requests.Cookie('probe', 'token')
      ..['expires'] = 'Wed, 01 Jan 2020 00:00:00 GMT'
      ..['max-age'] = '3600';
    await client.saveCookiesToLocal(requests.CookieJar()..['probe'] = cookie);
    final stored = jsonDecode(box.get('bilibili_cookies'));
    final expiry = stored['cookies'][0]['expiresAt'] as int;
    expect(expiry, greaterThan(DateTime.now().millisecondsSinceEpoch));
    final restored = await client.getCookiesFromLocal();
    expect(restored!['probe']!.value, 'token');
    expect(restored['probe']!['expires'], isNotNull);
    // Re-saving must not restart max-age from the current time.
    await client.saveCookiesToLocal(restored);
    final again = jsonDecode(box.get('bilibili_cookies'));
    expect(again['cookies'][0]['expiresAt'], lessThanOrEqualTo(expiry));
  });

  test('an expired cache triggers a fresh network fetch', () async {
    await box.put(
        'bilibili_cookies',
        jsonEncode({
          'version': 1,
          'cookies': [
            {'name': 'probe', 'value': 'old', 'expiresAt': 0}
          ],
        }));
    await client.init();
    expect(client.fetches, 1);
    expect(client.hasCookie, isTrue);
  });

  test('refresh removes stale memory cookies and replaces disk cookies',
      () async {
    await client.init();
    await requests.Requests.addCookie('www.bilibili.com', 'stale', 'old');
    await requests.Requests.addCookie('api.bilibili.com', 'stale', 'old');
    await client.refreshCookies();
    expect(client.fetches, 2);
    expect(
        await requests.Requests.getStoredCookies('www.bilibili.com'), isEmpty);
    final apiCookies =
        await requests.Requests.getStoredCookies('api.bilibili.com');
    expect(apiCookies.keys, ['probe']);
    expect(apiCookies['probe']!.value, 'fresh-token');
  });

  test('network failure leaves initialization false with no stale cache',
      () async {
    await client.init();
    client.failure = StateError('offline');
    await expectLater(client.refreshCookies(), throwsStateError);
    expect(client.hasCookie, isFalse);
    expect(box.containsKey('bilibili_cookies'), isFalse);
    expect(
        await requests.Requests.getStoredCookies('api.bilibili.com'), isEmpty);
  });

  test('empty or expired network cookies cannot mark initialization successful',
      () async {
    client.fresh = requests.CookieJar();
    await expectLater(client.init(), throwsStateError);
    expect(client.hasCookie, isFalse);
    client.fresh['deleted'] = requests.Cookie('deleted', 'x')
      ..['max-age'] = '0';
    await expectLater(client.init(), throwsStateError);
    expect(client.hasCookie, isFalse);
    expect(box.containsKey('bilibili_cookies'), isFalse);
  });
}

Future<void> _clearRequestCookies() async {
  await requests.Requests.clearStoredCookies('www.bilibili.com');
  await requests.Requests.clearStoredCookies('api.bilibili.com');
}
