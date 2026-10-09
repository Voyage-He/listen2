import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:listen2/src/provider/repo/bilibili.dart';
import 'package:listen2/src/view/page/search/search.page.dart';
import 'package:music_api/music_api.dart';

class _FakeBox extends Fake implements Box {}

class _SearchClient extends BilibiliClient {
  _SearchClient() : super(_FakeBox()) {
    hasCookie = true;
  }

  Future<List<BilibiliVideoModel>> Function(String) onSearch = (_) async => [];

  @override
  Future<List<BilibiliVideoModel>> search(String keyword) => onSearch(keyword);
}

void main() {
  late ProviderContainer container;
  late _SearchClient client;

  setUp(() async {
    client = _SearchClient();
    container = ProviderContainer(overrides: [
      bilibiliClientNotifierProvider
          .overrideWith(() => _ClientNotifier(client)),
    ]);
    container.listen(searchResultProvider, (_, __) {});
    await container.read(searchResultProvider.future);
    await container.read(bilibiliClientNotifierProvider.future);
    container.read(keywordNotifierProvider.notifier).update('song');
  });

  tearDown(() => container.dispose());

  test('empty search results do not throw', () async {
    await container.read(searchResultProvider.notifier).search();
    expect(container.read(searchResultProvider).requireValue, isEmpty);
  });

  test('network failures become provider error state', () async {
    client.onSearch = (_) async => throw StateError('offline');
    await container.read(searchResultProvider.notifier).search();
    expect(container.read(searchResultProvider).hasError, isTrue);
  });

  test('blank keywords clear results without sending a request', () async {
    client.onSearch = (_) async => throw StateError('must not search');
    container.read(keywordNotifierProvider.notifier).update('  ');
    await container.read(searchResultProvider.notifier).search();
    expect(container.read(searchResultProvider).requireValue, isEmpty);
  });

  test('a pending request can finish after the search page is disposed',
      () async {
    final response = Completer<List<BilibiliVideoModel>>();
    client.onSearch = (_) => response.future;
    final pending = container.read(searchResultProvider.notifier).search();
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    response.complete([]);
    await pending;
  });

  test('older responses cannot overwrite the latest search', () async {
    final first = Completer<List<BilibiliVideoModel>>();
    client.onSearch = (keyword) async {
      if (keyword == 'song') return first.future;
      return [];
    };
    final oldRequest = container.read(searchResultProvider.notifier).search();
    await Future<void>.delayed(Duration.zero);
    container.read(keywordNotifierProvider.notifier).update('new song');
    await container.read(searchResultProvider.notifier).search();
    first.completeError(StateError('old request failed'));
    await oldRequest;
    expect(container.read(searchResultProvider).requireValue, isEmpty);
  });
}

class _ClientNotifier extends BilibiliClientNotifier {
  _ClientNotifier(this.client);
  final BilibiliClient client;

  @override
  Future<BilibiliClient> build() async => client;
}
