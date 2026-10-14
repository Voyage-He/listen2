import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen2/src/widget/record_shelf.dart';

void main() {
  testWidgets('empty shelf and playlist tab are independently accessible',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var queue = 0;
    var playlists = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 288,
      child: RecordShelf(
          count: 0,
          covers: const [],
          onOpenQueue: () => queue++,
          onChoosePlaylist: () => playlists++),
    ))));
    await tester.tap(find.byKey(const ValueKey('record-shelf-open')));
    await tester.pumpAndSettle();
    expect(queue, 1);
    expect(playlists, 0);
    await tester.tap(find.byKey(const ValueKey('record-shelf-playlists')));
    await tester.pumpAndSettle();
    expect(queue, 1);
    expect(playlists, 1);
    expect(find.text('还没有唱片'), findsOneWidget);
    expect(
        tester.getSemantics(find.byKey(const ValueKey('record-shelf-open'))),
        matchesSemantics(
            label: '播放列表\n还没有唱片', hasTapAction: true, isFocusable: true));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
      'shelf fits small screens with large text and blocks busy navigation',
      (tester) async {
    var opened = 0;
    for (final busy in [false, true]) {
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!),
        home: Scaffold(
            body: SizedBox(
                width: 288,
                child: RecordShelf(
                    count: 1234,
                    busy: busy,
                    covers: const [
                      ColoredBox(color: Colors.red),
                      ColoredBox(color: Colors.green),
                      ColoredBox(color: Colors.blue)
                    ],
                    onOpenQueue: () => opened++,
                    onChoosePlaylist: () => opened++))),
      ));
      await tester.tap(find.byKey(const ValueKey('record-shelf-open')));
      await tester.tap(find.byKey(const ValueKey('record-shelf-playlists')));
      await tester.pumpAndSettle();
      expect(opened, 2);
      expect(tester.takeException(), isNull);
    }
    expect(find.text('请稍候…'), findsOneWidget);
  });
}
