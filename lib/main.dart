import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/storage.dart';
import 'package:listen2/src/provider/repo/bilibili.dart';
import 'package:listen2/src/provider/stateful/player.dart';

import 'src/view/home.page.dart';

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
            builder = (context) => const Home();
            break;
          default:
            throw Exception('Invalid route: ${settings.name}');
        }
        return PageRouteBuilder(
            pageBuilder: (context, _, __) => builder(context));
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
    var storage = ref.watch(hiveStorageProvider);
    ref.watch(bilibiliClientNotifierProvider);
    ref.watch(audioHandlerProvider);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark));
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    var w = storage.when(
      data: (data) => child,
      loading: () => const Text('loading'),
      error: (o, t) {
        debugPrint(o.toString());
        debugPrint(t.toString());
        return const Text('Error');
      },
    );

    return GestureDetector(
        onTap: () => Focus.of(context).requestFocus(FocusNode()),
        onVerticalDragStart: (_) => Focus.of(context).requestFocus(FocusNode()),
        child: Container(color: Colors.white, child: SafeArea(child: w)));
  }
}
