import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';

void main() {
  test('larger record and horizontal parked arm fit the deck', () {
    for (final width in [288.0, 358.0, 460.0]) {
      final geometry =
          VinylDeckGeometry(Size(width, width / VinylDeckGeometry.aspectRatio));
      expect(geometry.record.width, greaterThan(width * .9));
      expect(geometry.pivot.dx, lessThan(width * .2));
      expect(geometry.pivot.dy, greaterThan(geometry.record.bottom));
      expect(geometry.parkedTip.dx, greaterThan(width * .8));
      expect(geometry.parkedTip.dy, geometry.pivot.dy);
      final radius = geometry.record.width / 2;
      double groove(double progress) =>
          (geometry.tip(1, progress) - geometry.record.center).distance;
      expect(groove(0), greaterThan(radius * .9));
      expect(groove(0), lessThan(radius));
      expect(groove(1), greaterThan(radius * .35));
      expect(groove(1), lessThan(radius * .5));
      for (final progress in [0.0, .5, 1.0]) {
        for (final lowered in [0.0, .5, 1.0]) {
          final tip = geometry.tip(lowered, progress);
          expect((tip - geometry.pivot).distance,
              closeTo(geometry.armLength, .001));
          expect((Offset.zero & geometry.size).contains(tip), isTrue);
        }
      }
    }
  });

  Future<void> pumpDeck(WidgetTester tester,
      {bool enabled = true,
      bool playing = false,
      bool busy = false,
      bool reduceMotion = false,
      bool canSkipNext = true,
      bool canSkipPrevious = true,
      VinylTrackPreview? previousTrack,
      VinylTrackPreview? nextTrack,
      VoidCallback? longPress,
      VoidCallback? swipeUp,
      VoidCallback? swipeDown,
      Duration length = const Duration(minutes: 3),
      Future<void> Function(bool)? arm,
      Future<void> Function(Duration)? seek,
      Future<void> Function(int)? skip}) async {
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduceMotion),
            child: child!),
        home: Scaffold(
            body: Center(
                child: SizedBox(
          width: 360,
          child: VinylDeck(
              playing: playing,
              enabled: enabled,
              busy: busy,
              previousTrack: previousTrack,
              nextTrack: nextTrack,
              canSkipNext: canSkipNext,
              canSkipPrevious: canSkipPrevious,
              onLabelLongPress: longPress,
              onLabelSwipeUp: swipeUp,
              onLabelSwipeDown: swipeDown,
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

  testWidgets(
      'center long press opens library without a record and moving cancels it',
      (tester) async {
    var opened = 0;
    final skips = <int>[];
    await pumpDeck(tester, enabled: false, longPress: () => opened++);
    await tester.longPress(find.byKey(const ValueKey('vinyl-record')));
    await tester.pumpAndSettle();
    expect(opened, 1);
    await pumpDeck(tester,
        longPress: () => opened++, skip: (value) async => skips.add(value));
    final center = tester.getCenter(find.byKey(const ValueKey('vinyl-record')));
    final pointer = await tester.startGesture(center);
    await pointer.moveBy(const Offset(-90, 0));
    await tester.pump(const Duration(milliseconds: 600));
    await pointer.up();
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(skips, [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tonearm taps and drags land the needle', (tester) async {
    final moves = <bool>[];
    await pumpDeck(tester, arm: (value) async => moves.add(value));
    final deck = tester.getRect(find.byType(VinylDeck));
    final tip = deck.topLeft + VinylDeckGeometry(deck.size).parkedTip;
    await tester.tapAt(tip);
    await tester.pumpAndSettle();
    expect(moves, [true]);
    final drag = await tester.startGesture(tip);
    await tester.pump(vinylArmGrabDelay);
    await drag.moveBy(const Offset(0, -100));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(moves.last, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'quick tonearm taps stay visually steady and toggle playback on release',
      (tester) async {
    for (final playing in [false, true]) {
      final moves = <bool>[];
      await pumpDeck(tester,
          playing: playing,
          reduceMotion: true,
          arm: (value) async => moves.add(value));
      final deck = tester.getRect(find.byType(VinylDeck));
      final geometry = VinylDeckGeometry(deck.size);
      final tip = deck.topLeft + geometry.tip(playing ? 1 : 0, .25);
      CustomPainter painter() => tester
          .widget<CustomPaint>(find.descendant(
              of: find.byKey(const ValueKey('tonearm')),
              matching: find.byType(CustomPaint)))
          .painter!;
      final resting = painter();
      final tap = await tester.startGesture(tip);
      await tester.pump(const Duration(milliseconds: 100));
      await tap.moveBy(const Offset(2, -2));
      await tester.pump(const Duration(milliseconds: 30));
      expect(painter().shouldRepaint(resting), isFalse,
          reason: 'A short press must not lift or move the tonearm');
      expect(find.byKey(const ValueKey('tonearm-grab-hint')), findsNothing);
      expect(moves, isEmpty);
      await tap.up();
      await tester.pumpAndSettle();
      expect(moves, [!playing]);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('tonearm-grab-hint')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'tonearm grabs after the hold delay and holding without dragging does not toggle',
      (tester) async {
    final moves = <bool>[];
    await pumpDeck(tester, arm: (value) async => moves.add(value));
    final rect = tester.getRect(find.byType(VinylDeck));
    final geometry = VinylDeckGeometry(rect.size);
    final hold = await tester.startGesture(rect.topLeft + geometry.parkedTip);
    await tester.pump(vinylArmGrabDelay - const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey('tonearm-grab-hint')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey('tonearm-grab-hint')), findsOneWidget);
    await hold.up();
    await tester.pumpAndSettle();
    expect(moves, isEmpty);

    final drag = await tester.startGesture(rect.topLeft + geometry.parkedTip);
    await drag.moveTo(rect.topLeft + geometry.tip(1, .25));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('tonearm-grab-hint')), findsNothing);
    await tester.pump(vinylArmGrabDelay - const Duration(milliseconds: 100));
    expect(find.text('松手落针播放'), findsOneWidget);
    await drag.up();
    await tester.pumpAndSettle();
    expect(moves, [true]);
  });

  testWidgets(
      'early releases, cancellation, busy state and disposal cancel a pending arm grab',
      (tester) async {
    final moves = <bool>[];
    for (final ending in ['release', 'cancel', 'busy', 'dispose']) {
      await pumpDeck(tester, arm: (value) async => moves.add(value));
      final rect = tester.getRect(find.byType(VinylDeck));
      final geometry = VinylDeckGeometry(rect.size);
      final drag = await tester.startGesture(rect.topLeft + geometry.parkedTip);
      await drag.moveTo(rect.topLeft + geometry.tip(1, .25));
      await tester.pump(const Duration(milliseconds: 100));
      if (ending == 'release') {
        await drag.up();
      } else if (ending == 'cancel') {
        await drag.cancel();
      } else if (ending == 'busy') {
        await pumpDeck(tester,
            busy: true, arm: (value) async => moves.add(value));
        await drag.up();
      } else {
        await tester.pumpWidget(const SizedBox.shrink());
        await drag.up();
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('tonearm-grab-hint')), findsNothing);
      expect(moves, isEmpty);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'slow tonearm drags own the pointer before page navigation and scrolling',
      (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var pageSwipes = 0;
    final moves = <bool>[];
    final seeks = <Duration>[];
    final skips = <int>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
      width: 360,
      height: 470,
      child: GestureDetector(
        onHorizontalDragUpdate: (_) => pageSwipes++,
        child: SingleChildScrollView(
            controller: scroll,
            child: Column(children: [
              VinylDeck(
                playing: false,
                position: const Duration(seconds: 45),
                duration: const Duration(minutes: 3),
                cover: const ColoredBox(color: vinylGold),
                onArmChanged: (value) async => moves.add(value),
                onSeek: (value) async => seeks.add(value),
                onSkip: (value) async => skips.add(value),
              ),
              const SizedBox(height: 700),
            ])),
      ),
    )))));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(VinylDeck));
    final geometry = VinylDeckGeometry(rect.size);
    final start = rect.topLeft + geometry.parkedTip;
    for (final destination in [
      start + const Offset(-110, 0),
      rect.topLeft + geometry.tip(1, .25),
    ]) {
      final drag = await tester.startGesture(start);
      for (var index = 1; index <= 20; index++) {
        await drag.moveTo(Offset.lerp(start, destination, index / 20)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await drag.up();
      await tester.pumpAndSettle();
      expect(pageSwipes, 0,
          reason: 'A slow arm drag must never become page navigation');
      expect(scroll.offset, 0,
          reason: 'Dragging the needle must not scroll the page');
    }
    expect(moves, [true]);
    expect(seeks, isEmpty);
    expect(skips, isEmpty);
    // Other parts of the player retain normal navigation and vertical scrolling.
    await tester.dragFrom(
        rect.topLeft + const Offset(3, 100), const Offset(90, 0));
    await tester.pumpAndSettle();
    expect(pageSwipes, greaterThan(0));
    await tester.dragFrom(
        rect.topLeft + const Offset(3, 100), const Offset(0, -90));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tonearm only commits at a landing zone and cancellation restores it',
      (tester) async {
    final moves = <bool>[];
    await pumpDeck(tester, arm: (value) async => moves.add(value));
    final deck = tester.getRect(find.byType(VinylDeck));
    final geometry = VinylDeckGeometry(deck.size);
    final origin = deck.topLeft + geometry.parkedTip;
    final halfway = deck.topLeft + geometry.tip(.5, .25);
    final partial = await tester.startGesture(origin);
    await tester.pump(vinylArmGrabDelay);
    await partial.moveTo(halfway);
    await tester.pump();
    expect(find.byKey(const ValueKey('tonearm-grab-hint')), findsOneWidget);
    expect(find.text('松手落针播放'), findsNothing);
    await partial.up();
    await tester.pumpAndSettle();
    expect(moves, isEmpty);
    expect(find.byKey(const ValueKey('tonearm-grab-hint')), findsNothing);

    final cancelled = await tester.startGesture(origin);
    await tester.pump(vinylArmGrabDelay);
    await cancelled.moveTo(deck.topLeft + geometry.tip(1, .25));
    await tester.pump();
    expect(find.text('松手落针播放'), findsOneWidget);
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(moves, isEmpty);
    expect(find.byKey(const ValueKey('tonearm-grab-hint')), findsNothing);

    await pumpDeck(tester,
        playing: true,
        reduceMotion: true,
        arm: (value) async => moves.add(value));
    final returned =
        await tester.startGesture(deck.topLeft + geometry.tip(1, .25));
    await tester.pump(vinylArmGrabDelay);
    await returned.moveTo(origin);
    await tester.pump();
    expect(find.text('松手归位暂停'), findsOneWidget);
    await returned.up();
    await tester.pumpAndSettle();
    expect(moves, [false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tonearm snap survives small finger jitter and follows dragging immediately',
      (tester) async {
    final moves = <bool>[];
    await pumpDeck(tester, arm: (value) async => moves.add(value));
    final deck = tester.getRect(find.byType(VinylDeck));
    final geometry = VinylDeckGeometry(deck.size);
    final drag = await tester.startGesture(deck.topLeft + geometry.parkedTip);
    await tester.pump(vinylArmGrabDelay);
    await drag.moveTo(deck.topLeft + geometry.tip(.9, .25));
    await tester.pump();
    expect(find.text('松手落针播放'), findsOneWidget);
    final armTween = tester.widget<TweenAnimationBuilder<double>>(
        find.descendant(
            of: find.byType(VinylDeck),
            matching: find.byType(TweenAnimationBuilder<double>)));
    expect(armTween.duration, Duration.zero);
    await drag.moveTo(deck.topLeft + geometry.tip(.8, .25));
    await tester.pump();
    expect(find.text('松手落针播放'), findsOneWidget);
    await drag.up();
    await tester.pumpAndSettle();
    expect(moves, [true]);
  });

  testWidgets(
      'becoming busy releases a grabbed arm without committing playback',
      (tester) async {
    final moves = <bool>[];
    Future<void> onArm(bool value) async => moves.add(value);
    await pumpDeck(tester, arm: onArm);
    final rect = tester.getRect(find.byType(VinylDeck));
    final geometry = VinylDeckGeometry(rect.size);
    final drag = await tester.startGesture(rect.topLeft + geometry.parkedTip);
    await tester.pump(vinylArmGrabDelay);
    await drag.moveTo(rect.topLeft + geometry.tip(1, .25));
    await tester.pump();
    expect(find.text('松手落针播放'), findsOneWidget);
    await pumpDeck(tester, busy: true, arm: onArm);
    expect(find.byKey(const ValueKey('tonearm-grab-hint')), findsNothing);
    await drag.up();
    await tester.pumpAndSettle();
    expect(moves, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'track preview follows direction and threshold haptic fires once per direction',
      (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final skips = <int>[];
    await pumpDeck(tester,
        previousTrack: const VinylTrackPreview(
            title: '前一张封面', cover: ColoredBox(color: Colors.blue)),
        nextTrack: const VinylTrackPreview(
            title: '下一张封面', cover: ColoredBox(color: Colors.red)),
        skip: (value) async => skips.add(value));
    final center = tester.getCenter(find.byKey(const ValueKey('vinyl-record')));
    final drag = await tester.startGesture(center);
    await drag.moveTo(center + const Offset(-30, 0));
    await tester.pump();
    expect(find.text('下一张封面'), findsOneWidget);
    expect(find.text('继续拨动换曲'), findsOneWidget);
    expect(haptics, isEmpty);
    await drag.moveTo(center + const Offset(-60, 0));
    await tester.pump();
    expect(find.text('松手换下一张'), findsOneWidget);
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    expect(skips, isEmpty);
    await drag.moveTo(center + const Offset(-40, 0));
    await drag.moveTo(center + const Offset(-65, 0));
    await tester.pump();
    expect(haptics, hasLength(1));
    await drag.moveTo(center + const Offset(65, 0));
    await tester.pump();
    expect(find.text('前一张封面'), findsOneWidget);
    expect(find.text('松手换上一张'), findsOneWidget);
    expect(haptics, hasLength(2));
    await drag.up();
    await tester.pumpAndSettle();
    expect(skips, [-1]);
    expect(haptics, hasLength(2));
    expect(find.byKey(const ValueKey('vinyl-skip-preview')), findsNothing);
  });

  testWidgets(
      'short swipes, dragging back and cancelled previews do not switch tracks',
      (tester) async {
    final skips = <int>[];
    await pumpDeck(tester, skip: (value) async => skips.add(value));
    final center = tester.getCenter(find.byKey(const ValueKey('vinyl-record')));
    for (final cancel in [false, true]) {
      final drag = await tester.startGesture(center);
      await drag.moveTo(center + const Offset(-70, 0));
      await tester.pump();
      expect(find.text('松手换下一张'), findsOneWidget);
      if (cancel) {
        await drag.cancel();
      } else {
        await drag.moveTo(center + const Offset(-30, 0));
        await drag.up();
      }
      await tester.pumpAndSettle();
      expect(skips, isEmpty);
      expect(find.byKey(const ValueKey('vinyl-skip-preview')), findsNothing);
    }
    await tester.dragFrom(center, const Offset(30, 0));
    await tester.pumpAndSettle();
    expect(skips, isEmpty);
  });

  testWidgets('queue boundaries show a reason without a ready-to-switch cue',
      (tester) async {
    await pumpDeck(tester,
        canSkipNext: false, canSkipPrevious: false, reduceMotion: true);
    final center = tester.getCenter(find.byKey(const ValueKey('vinyl-record')));
    for (final direction in [-1, 1]) {
      final drag = await tester.startGesture(center);
      await drag.moveBy(Offset(direction * 90.0, 0));
      await tester.pump();
      expect(find.text(direction < 0 ? '最后一张了' : '第一张了'), findsOneWidget);
      expect(find.textContaining('松手换'), findsNothing);
      await drag.up();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('an empty record does not pretend to preview a neighboring track',
      (tester) async {
    await pumpDeck(tester, enabled: false, swipeUp: () {});
    final record = find.byKey(const ValueKey('vinyl-record'));
    final drag = await tester.startGesture(tester.getCenter(record));
    await drag.moveBy(const Offset(-80, 0));
    await tester.pump();
    expect(find.byKey(const ValueKey('vinyl-skip-preview')), findsNothing);
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press builds nonlinearly and cancellation restores scale',
      (tester) async {
    var opened = 0;
    await pumpDeck(tester, longPress: () => opened++);
    final record = find.byKey(const ValueKey('vinyl-record'));
    double scale() => tester
        .widget<Transform>(
            find.descendant(of: record, matching: find.byType(Transform)).at(1))
        .transform
        .storage[0];
    final pointer = await tester.startGesture(tester.getCenter(record));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final early = scale();
    await tester.pump(const Duration(milliseconds: 100));
    final later = scale();
    expect(early, lessThan(1));
    expect(later, lessThan(early));
    expect(early - later, greaterThan(1 - early));
    expect(opened, 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(opened, 1);
    await pointer.up();
    await tester.pumpAndSettle();
    expect(scale(), closeTo(1, .001));
    final cancelled = await tester.startGesture(tester.getCenter(record));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(), lessThan(1));
    await cancelled.cancel();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    expect(opened, 1);
    expect(scale(), closeTo(1, .001));
    expect(tester.takeException(), isNull);
  });

  for (final direction in [-1, 1]) {
    testWidgets(
        'vertical label pulls dampen and ease back in direction $direction',
        (tester) async {
      var opened = 0;
      final skips = <int>[];
      final seeks = <Duration>[];
      await pumpDeck(tester,
          swipeUp: direction < 0 ? () => opened++ : null,
          swipeDown: direction > 0 ? () => opened++ : null,
          skip: (value) async => skips.add(value),
          seek: (value) async => seeks.add(value));
      final record = find.byKey(const ValueKey('vinyl-record'));
      double offset() =>
          tester
              .widget<Transform>(find
                  .descendant(of: record, matching: find.byType(Transform))
                  .first)
              .transform
              .storage[13] *
          direction;
      final pointer = await tester.startGesture(tester.getCenter(record));
      await pointer.moveBy(Offset(0, 80.0 * direction));
      await tester.pump();
      final first = offset();
      await pointer.moveBy(Offset(0, 80.0 * direction));
      await tester.pump();
      final displaced = offset();
      expect(first, greaterThan(0));
      expect(displaced, greaterThan(first));
      expect(displaced - first, lessThan(first));
      expect(opened, 0);
      await pointer.up();
      await tester.pump();
      expect(offset(), closeTo(displaced, .01));
      expect(opened, 1);
      await tester.pump(const Duration(milliseconds: 140));
      expect(offset(), greaterThan(0));
      expect(offset(), lessThan(displaced / 2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(offset(), closeTo(0, .01));
      expect(skips, isEmpty);
      expect(seeks, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'upward label swipe opens an empty shelf and ignores cancellation',
      (tester) async {
    var shelves = 0;
    var libraries = 0;
    var collections = 0;
    final skips = <int>[];
    final seeks = <Duration>[];
    await pumpDeck(tester,
        enabled: false,
        longPress: () => libraries++,
        swipeUp: () => shelves++,
        swipeDown: () => collections++,
        skip: (value) async => skips.add(value),
        seek: (value) async => seeks.add(value));
    final record = find.byKey(const ValueKey('vinyl-record'));
    await tester.drag(record, const Offset(0, -30));
    await tester.pumpAndSettle();
    expect(shelves, 0);
    final pointer = await tester.startGesture(tester.getCenter(record));
    await pointer.moveBy(const Offset(0, -100));
    await pointer.cancel();
    await tester.pumpAndSettle();
    expect(shelves, 0);
    await tester.drag(record, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(shelves, 1);
    await tester.drag(record, const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(collections, 0);
    expect(libraries, 0);
    expect(skips, isEmpty);
    expect(seeks, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps label gestures without animation',
      (tester) async {
    var libraries = 0;
    var collections = 0;
    await pumpDeck(tester,
        reduceMotion: true,
        longPress: () => libraries++,
        swipeDown: () => collections++);
    final record = find.byKey(const ValueKey('vinyl-record'));
    final pointer = await tester.startGesture(tester.getCenter(record));
    await tester.pump(const Duration(milliseconds: 250));
    var transforms = tester
        .widgetList<Transform>(
            find.descendant(of: record, matching: find.byType(Transform)))
        .toList();
    expect(transforms[1].transform.storage[0], 1);
    await pointer.moveBy(const Offset(0, 100));
    await tester.pump();
    transforms = tester
        .widgetList<Transform>(
            find.descendant(of: record, matching: find.byType(Transform)))
        .toList();
    expect(transforms[0].transform.storage[13], 0);
    await pointer.up();
    await tester.pumpAndSettle();
    expect(collections, 1);
    expect(libraries, 0);
    await tester.longPress(record);
    await tester.pumpAndSettle();
    expect(libraries, 1);
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
        viewport.bottomLeft + const Offset(3, -20), const Offset(0, -80));
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
    await tester.tapAt(deck.topLeft + VinylDeckGeometry(deck.size).parkedTip);
    await tester.pumpAndSettle();
    expect(arms, isEmpty);
  });
}
