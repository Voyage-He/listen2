import 'package:flutter/material.dart';
import 'package:listen2/src/widget/app_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/main.dart';

import 'package:listen2/src/view/page/player/player.page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ListenApp()));
}

class ListenApp extends StatelessWidget {
  const ListenApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: AppStyle.theme,
        title: 'Listen 2',
        debugShowCheckedModeBanner: false,
        home: const Player(isHome: true),
        builder: (context, child) => App(child: child!),
      );
}

class App extends ConsumerWidget {
  const App({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // global initialize and config settings
    final isReady = ref.watch(globalReadyProvider);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false));
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    const splash = SafeArea(child: Center(child: CircularProgressIndicator()));

    var w = isReady.when(
      data: (data) => child,
      loading: () => splash,
      error: (obj, stackTrace) {
        debugPrint(obj.toString());
        debugPrint(stackTrace.toString());
        return SafeArea(
            child: EmptyState(
                icon: Icons.wifi_off_rounded,
                title: '初始化失败',
                message: '请检查网络后重试',
                action: FilledButton(
                    onPressed: () => ref.invalidate(globalReadyProvider),
                    child: const Text('重试'))));
      },
    );

    return Scaffold(
      body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          onVerticalDragStart: (_) =>
              FocusManager.instance.primaryFocus?.unfocus(),
          child: Material(color: AppStyle.background, child: w)),
    );
  }
}
