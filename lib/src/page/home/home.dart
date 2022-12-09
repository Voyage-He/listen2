import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../search/search.view.dart';

import '../../widget/button/button.dart';
import '../../global/player/player.logic.dart';

class Home extends ConsumerWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      // decoration: const BoxDecoration(color: Colors.white),
      child: Stack(
        children: [
          Row(
            children: [
              Button(child: const Text("start"), circle: true, onTap: () {print("====start====");}),
              Button(child: const Text("pause"), circle: true, onTap: () {print("====pause====");},)
            ],
          ),
          Positioned(
            bottom: 10.0,
            right: 10.0,
            child: Button(child: const Text("stop"), circle: true, onTap: () 
              {
                print("nav");
                Navigator.of(context).push(
                  PageRouteBuilder(pageBuilder:(context, _, __) => const Search(),)
                );
              },
            )
          )
        ],
      )
    );
  }
}