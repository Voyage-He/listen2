import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import './src/global/main.dart';

import 'src/page/home.view.dart';

import 'src/bloc/player.cubit.dart';
import 'src/bloc/favorite.cubit.dart';

import 'src/repo/track.repo.dart';

Future globalInit() async {
  Future.wait([
    Globals.init(),
    TrackRepo().init()
  ]);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await globalInit();
  
  runApp(WidgetsApp(
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
          builder = (context) => const Home();
          break;
        default: 
          throw Exception('Invalid route: ${settings.name}');
      }
      return PageRouteBuilder(pageBuilder: (context, _, __) => builder(context));
    },
    builder: (context, child) => App(child: child!),
  ));
}

class App extends StatelessWidget {
  const App({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => FavoriteCubit()..getTracks()),
        BlocProvider(create: (context) => PlayerCubit()),
      ],
      child: GestureDetector(
        onTap: () => Focus.of(context).requestFocus(FocusNode()),
        onVerticalDragStart: (_) => Focus.of(context).requestFocus(FocusNode()),
        // onDrag 
        child: Container(
          color: Colors.white,
          child: SafeArea(child: child)
        )
      ),
    );
  }
}
