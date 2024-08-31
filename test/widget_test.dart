// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:listen2/src/provider/global/storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:listen2/src/provider/stateful/favorite.dart';
import 'package:listen2/src/view/favorite.page.dart';

/// A testing utility which creates a [ProviderContainer] and automatically
/// disposes it at the end of the test.
ProviderContainer createContainer({
  ProviderContainer? parent,
  List<Override> overrides = const [],
  List<ProviderObserver>? observers,
}) {
  // Create a ProviderContainer, and optionally allow specifying parameters.
  final container = ProviderContainer(
    parent: parent,
    overrides: overrides,
    observers: observers,
  );

  // When the test ends, dispose the container.
  addTearDown(container.dispose);

  return container;
}

void main() {
  group('setup', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => 'test',
    );
    test('hiveStorage-init', () async {
      final container = createContainer();

      var storage = await container.read(hiveStorageProvider.future);

      assert(storage.value.get('favorites')[0] == '1aE411n7wb');
    });

    test('favo-provider', () async {
      final container = createContainer();

      var tracks = await container.read(favoriteTracksProvider.future);
      print(tracks);
    });
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {});
}
