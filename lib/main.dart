import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/main.dart';

import 'package:listen2/src/view/page/home/home.page.dart';
import 'package:listen2/src/widget/bottom_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(ProviderScope(
    child: WidgetsApp(
      title: "listen2 music player",
      color: Colors.white,
      textStyle: const TextStyle(fontSize: 18, color: Colors.black),
      debugShowCheckedModeBanner: false,
      // home: const Home(),
      initialRoute: '/',
      onGenerateRoute: (RouteSettings settings) {
        WidgetBuilder builder;
        switch (settings.name) {
          case '/':
            builder = (context) => Home();
            break;
          default:
            throw Exception('Invalid route: ${settings.name}');
        }
        return PageRouteBuilder(
            pageBuilder: (context, _, __) => Builder(builder: (context) {
              final subNavigatorKey = GlobalKey<NavigatorState>();
                  return Column(
                    children: [
                      Expanded(
                          child: PopScope(
                            canPop: false,
                            onPopInvokedWithResult: (didPop, result) async {
                              if (subNavigatorKey.currentState!.canPop()) {
                                subNavigatorKey.currentState!.pop();
                                return;
                              }
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              } else {
                                SystemNavigator.pop();
                              }
                            },
                            child: Navigator(
                              key: subNavigatorKey,
                              initialRoute: '/',
                              onGenerateRoute: (settings) {
                                return PageRouteBuilder(
                                    pageBuilder: (context, _, __) =>
                                        builder(context));
                              },
                            ),
                          )),
                      const BottomPlayer()
                    ],
                  );
                }));
      },
      builder: (context, child) => App(child: child!),
    ),
  ));
}

class App extends ConsumerWidget {
  const App({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // global initialize and config settings
    final isReady = ref.watch(globalReadyProvider);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark));
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    const splash = Text('initialzing');

    var w = isReady.when(
      data: (data) => child,
      loading: () => splash,
      error: (obj, stackTrace) {
        debugPrint(obj.toString());
        debugPrint(stackTrace.toString());
        return const Text('Error');
      },
    );

    return GestureDetector(
        onTap: () => Focus.of(context).requestFocus(FocusNode()),
        onVerticalDragStart: (_) => Focus.of(context).requestFocus(FocusNode()),
        child: SafeArea(
          child: Container(color: Colors.white, child: w),
        ));
  }
}
