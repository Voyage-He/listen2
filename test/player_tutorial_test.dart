import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen2/src/widget/app_style.dart';
import 'package:listen2/src/widget/player_tutorial.dart';
import 'package:listen2/src/widget/vinyl_deck.dart';

void main() {
  Future<void> openTutorial(WidgetTester tester,
      {Size size = const Size(390, 844),
      double scale = 1,
      bool isHome = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppStyle.theme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              disableAnimations: true, textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => showDialog<void>(
                context: context,
                useSafeArea: false,
                builder: (_) => PlayerTutorial(isHome: isHome)),
            child: const Text('打开教程'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('打开教程'));
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
  }

  testWidgets('all seven real gestures work on the local practice deck',
      (tester) async {
    await openTutorial(tester);
    final record = find.byKey(const ValueKey('vinyl-record'));
    final deck = find.byKey(const ValueKey('tutorial-practice-deck'));
    expect(find.text('第 1 / 7 步'), findsOneWidget);
    await tester.longPress(record);
    await tester.pumpAndSettle();
    expect(find.text('练习歌单'), findsOneWidget);
    await tester.tap(find.text('练习唱片 B'));
    await tester.pumpAndSettle();
    expect(find.text('已选好练习唱片'), findsOneWidget);

    await next(tester);
    final rect = tester.getRect(deck);
    await tester.tapAt(rect.topLeft + VinylDeckGeometry(rect.size).parkedTip);
    await tester.pumpAndSettle();
    expect(find.text('已学会控制唱针'), findsOneWidget);

    await next(tester);
    final recordRect = tester.getRect(record);
    final radius = recordRect.width * .4;
    final scrub =
        await tester.startGesture(recordRect.center + Offset(radius, 0));
    for (var index = 1; index <= 12; index++) {
      final angle = math.pi / 2 * index / 12;
      await scrub.moveTo(recordRect.center +
          Offset(math.cos(angle), math.sin(angle)) * radius);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await scrub.up();
    await tester.pumpAndSettle();
    expect(find.text('已调整练习唱片的进度'), findsOneWidget);

    await next(tester);
    await tester.drag(record, const Offset(-90, 0));
    await tester.pumpAndSettle();
    expect(find.text('已切换练习唱片'), findsOneWidget);

    await next(tester);
    await tester.drag(record, const Offset(0, -90));
    await tester.pumpAndSettle();
    expect(find.text('练习播放列表'), findsOneWidget);
    await tester.tap(find.text('练习唱片 A'));
    await tester.pumpAndSettle();
    expect(find.text('已打开练习播放列表'), findsOneWidget);

    await next(tester);
    await tester.drag(record, const Offset(0, 90));
    await tester.pumpAndSettle();
    expect(find.text('练习收藏'), findsOneWidget);
    await tester.tap(find.text('我喜欢的音乐'));
    await tester.pumpAndSettle();
    expect(find.text('已演示收藏到歌单'), findsOneWidget);

    await next(tester);
    final outside = tester.getRect(deck).centerLeft + const Offset(3, 0);
    final swipe = await tester.startGesture(outside);
    await swipe.moveBy(const Offset(100, 0));
    await swipe.up();
    await tester.pumpAndSettle();
    expect(find.text('已学会切换侧页'), findsOneWidget);
    await tester.tap(find.text('完成教程'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerTutorial), findsNothing);
    expect(find.text('打开教程'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tutorial remains navigable on a small screen with large text',
      (tester) async {
    await openTutorial(tester,
        size: const Size(320, 568), scale: 1.6, isHome: false);
    expect(find.text('第 1 / 6 步'), findsOneWidget);
    await next(tester);
    await tester.tap(find.text('上一步'));
    await tester.pumpAndSettle();
    expect(find.text('先选一张唱片'), findsOneWidget);
    for (var index = 1; index < 6; index++) {
      await next(tester);
      expect(tester.takeException(), isNull);
    }
    expect(find.text('第 6 / 6 步'), findsOneWidget);
    expect(find.text('完成教程'), findsOneWidget);
    await tester.tap(find.byTooltip('退出教程'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerTutorial), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
