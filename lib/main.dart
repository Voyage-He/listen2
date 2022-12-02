import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import './src/page/home/home.dart';
import 'src/page/search/search.view.dart';

import './src/global/player/player.logic.dart';

void main() {
  runApp(ProviderScope(child: WidgetsApp(
    title: "this own title",
    color: Colors.white,
    textStyle: const TextStyle(
      fontSize: 40, 
      color: Colors.black
    ),
    debugShowCheckedModeBanner: false,
    // home: const Home(),
    initialRoute: '/',
    onGenerateRoute: (RouteSettings settings) {
      WidgetBuilder builder;
      switch (settings.name) {
        case '/':
          builder = (context) => const Search();
          break;
        default: 
          throw Exception('Invalid route: ${settings.name}');
      }
      return PageRouteBuilder(pageBuilder: (context, _, __) => builder(context));
    },
    builder: (context, child) => App(child: child!),
  )));
}

class App extends ConsumerWidget {
  const App({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(playerPrvd);

    return GestureDetector(
      onTap: () => Focus.of(context).requestFocus(FocusNode()),
      onVerticalDragStart: (_) => Focus.of(context).requestFocus(FocusNode()),
      // onDrag
      child: Column(
        children: [
          Expanded(child: Container(
            width: double.infinity,
            color: Colors.white,
            child: const Text("appbar"))),
          Expanded(flex: 10,child: child)
        ],
      )
    );
  }
}
