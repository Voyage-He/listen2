import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:music_api/music_api.dart';

class _Box extends Fake implements Box {}

class _Client extends BilibiliClient {
  _Client() : super(_Box());
  final pages = <int>[];
  final ids = <String>[];
  final responses = <Response>[];

  @override
  Future<Response> getFavoritePage(String mediaId, int page) async {
    ids.add(mediaId);
    pages.add(page);
    return responses[page - 1];
  }
}

Map<String, dynamic> _media(String id) => {
      'bvid': id,
      'id': 1,
      'title': '<em>Song</em>',
      'cover': '//example.com/cover.jpg',
      'upper': {'name': 'Artist', 'mid': 1},
    };

Response _page(List<Map<String, dynamic>> medias, {bool more = false}) =>
    Response(
        jsonEncode({
          'code': 0,
          'data': {'medias': medias, 'has_more': more}
        }),
        200);

void main() {
  test('favorites follow pagination, normalize IDs and keep collection order',
      () async {
    final client = _Client()
      ..responses.addAll([
        _page([_media('BVfirst'), _media('BVsecond')], more: true),
        _page([_media('BVsecond'), _media(''), _media('BVthird')]),
      ]);
    final result = await client.getFavoriteList('123456');
    expect(client.pages, [1, 2]);
    expect(client.ids, ['123456', '123456']);
    expect(result.map((video) => video.bvid), ['first', 'second', 'third']);
    expect(result.first.title, 'Song');
    expect(result.first.author, 'Artist');
    expect(result.first.pic, '//example.com/cover.jpg');
  });

  test('empty favorites are valid', () async {
    final client = _Client()
      ..responses.add(Response(
          jsonEncode({
            'code': 0,
            'data': {'medias': null, 'has_more': false}
          }),
          200));
    expect(await client.getFavoriteList('123'), isEmpty);
  });

  test('invalid IDs do not send a request', () async {
    final client = _Client();
    for (final id in ['', '0', '-1', 'BV123', '123abc']) {
      await expectLater(client.getFavoriteList(id), throwsFormatException);
    }
    expect(client.pages, isEmpty);
  });

  test('private or missing favorites and HTTP failures propagate', () async {
    for (final response in [
      Response(jsonEncode({'code': -403, 'message': 'private'}), 200),
      Response('unavailable', 503),
    ]) {
      final client = _Client()..responses.add(response);
      await expectLater(client.getFavoriteList('123'), throwsStateError);
    }
  });

  test('failed later page does not return an incomplete playlist', () async {
    final client = _Client()
      ..responses.addAll([
        _page([_media('BVfirst')], more: true),
        Response('unavailable', 503),
      ]);
    await expectLater(client.getFavoriteList('123'), throwsStateError);
  });

  test('missing page with has_more cannot loop forever', () async {
    final client = _Client()..responses.add(_page([], more: true));
    await expectLater(client.getFavoriteList('123'), throwsFormatException);
    expect(client.pages, [1]);
  });
}
