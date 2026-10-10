import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';

void main() {
  Future<void> pumpDeck(WidgetTester tester,
      {bool enabled = true,
      Duration length = const Duration(minutes: 3),
      Future<void> Function(bool)? arm,
      Future<void> Function(Duration)? seek,
      Future<void> Function(int)? skip}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
      width: 360,
      child: VinylDeck(
          playing: false,
          enabled: enabled,
          position: const Duration(seconds: 45),
          duration: length,
          cover: const ColoredBox(color: vinylGold),
          onArmChanged: arm ?? (_) async {},
          onSeek: seek ?? (_) async {},
          onSkip: skip ?? (_) async {}),
    )))));
    await tester.pumpAndSettle();
  }

  testWidgets('record follows audio time at one revolution per minute',
      (tester) async {
    Future<void> show(Duration position, bool playing) =>
        tester.pumpWidget(MaterialApp(
          home: SizedBox(
              width: 200,
              height: 200,
              child: VinylRecord(
                  position: position,
                  playing: playing,
                  cover: const ColoredBox(color: vinylGold))),
        ));
    double angle() {
      final transform = tester.widget<Transform>(find.descendant(
          of: find.byType(VinylRecord), matching: find.byType(Transform)));
      return math.atan2(
          transform.transform.storage[1], transform.transform.storage[0]);
    }

    await show(const Duration(seconds: 15), false);
    expect(angle(), closeTo(math.pi / 2, .001));
    await tester.pump(const Duration(seconds: 10));
    expect(angle(), closeTo(math.pi / 2, .001));
    await show(const Duration(seconds: 15), true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(angle(), closeTo(2 * math.pi / 3, .001));
    await show(const Duration(seconds: 30), false);
    expect(angle().abs(), closeTo(math.pi, .001));
    await show(Duration.zero, false);
    expect(angle(), closeTo(0, .001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tonearm taps and drags land the needle', (tester) async {
    final moves = <bool>[];
    await pumpDeck(tester, arm: (value) async => moves.add(value));
    final deck = tester.getRect(find.byType(VinylDeck));
    final tip = deck.topLeft + Offset(deck.width * .885, deck.height * .72);
    await tester.tapAt(tip);
    await tester.pumpAndSettle();
    expect(moves, [true]);
    final drag = await tester.startGesture(tip);
    await drag.moveBy(const Offset(-100, 0));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(moves.last, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('center swipes change tracks without seeking', (tester) async {
    final skips = <int>[];
    final seeks = <Duration>[];
    await pumpDeck(tester,
        seek: (value) async => seeks.add(value),
        skip: (value) async => skips.add(value));
    final record = find.byKey(const ValueKey('vinyl-record'));
    await tester.drag(record, const Offset(-90, 0));
    await tester.pumpAndSettle();
    await tester.drag(record, const Offset(90, 0));
    await tester.pumpAndSettle();
    expect(skips, [1, -1]);
    expect(seeks, isEmpty);
  });

  testWidgets('outer rotations seek in both directions without switching',
      (tester) async {
    final seeks = <Duration>[];
    final skips = <int>[];
    await pumpDeck(tester,
        seek: (value) async => seeks.add(value),
        skip: (value) async => skips.add(value));
    final rect = tester.getRect(find.byKey(const ValueKey('vinyl-record')));
    final radius = rect.width * .43;
    for (final direction in [1, -1]) {
      final gesture =
          await tester.startGesture(rect.center + Offset(0, -radius));
      for (var i = 1; i <= 12; i++) {
        final angle = -math.pi / 2 + direction * math.pi / 2 * i / 12;
        await gesture.moveTo(
            rect.center + Offset(math.cos(angle), math.sin(angle)) * radius);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }
    expect(seeks.length, 2);
    expect(seeks[0].inMilliseconds, closeTo(60000, 1500));
    expect(seeks[1].inMilliseconds, closeTo(30000, 1500));
    expect(skips, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vertical record gestures do not scroll the surrounding page',
      (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final seeks = <Duration>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
      child: SizedBox(
        width: 360,
        height: 420,
        child: SingleChildScrollView(
            controller: scroll,
            child: Column(children: [
              VinylDeck(
                  playing: false,
                  position: const Duration(seconds: 45),
                  duration: const Duration(minutes: 3),
                  cover: const ColoredBox(color: vinylGold),
                  onArmChanged: (_) async {},
                  onSeek: (value) async => seeks.add(value),
                  onSkip: (_) async {}),
              const SizedBox(height: 700),
            ])),
      ),
    ))));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(const ValueKey('vinyl-record')));
    await tester.dragFrom(
        rect.centerLeft + const Offset(14, 0), const Offset(0, -90));
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    expect(seeks, hasLength(1));
    expect(seeks.single, greaterThan(const Duration(seconds: 45)));
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    await tester.dragFrom(
        viewport.bottomCenter - const Offset(0, 20), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejected track swipes ease back instead of snapping',
      (tester) async {
    final skips = <int>[];
    await pumpDeck(tester, skip: (direction) async => skips.add(direction));
    final record = find.byKey(const ValueKey('vinyl-record'));
    double offset() => tester
        .widget<Transform>(
            find.descendant(of: record, matching: find.byType(Transform)).first)
        .transform
        .storage[12];
    final gesture = await tester.startGesture(tester.getCenter(record));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    final displaced = offset();
    expect(displaced, lessThan(-5));
    await gesture.up();
    await tester.pump();
    expect(offset(), closeTo(displaced, .01));
    expect(skips, [1]);
    await tester.pump(const Duration(milliseconds: 120));
    expect(offset(), greaterThan(displaced));
    expect(offset(), lessThan(-.1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(offset(), closeTo(0, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown duration and missing record disable seeking',
      (tester) async {
    final seeks = <Duration>[];
    await pumpDeck(tester,
        length: Duration.zero, seek: (value) async => seeks.add(value));
    final rect = tester.getRect(find.byKey(const ValueKey('vinyl-record')));
    await tester.dragFrom(
        rect.topCenter + const Offset(0, 12), const Offset(70, 40));
    await tester.pumpAndSettle();
    expect(seeks, isEmpty);
    final arms = <bool>[];
    await pumpDeck(tester,
        enabled: false, arm: (value) async => arms.add(value));
    final deck = tester.getRect(find.byType(VinylDeck));
    await tester
        .tapAt(deck.topLeft + Offset(deck.width * .885, deck.height * .72));
    await tester.pumpAndSettle();
    expect(arms, isEmpty);
  });
}
