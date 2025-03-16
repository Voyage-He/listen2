import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:listen2/src/provider/global/file_storage.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/widget/button/button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Option extends ConsumerWidget {
  const Option({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Button(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: const Text('return')),
        Button(
            onTap: () async {
              final result = await FilePicker.platform.getDirectoryPath();

              if (result != null) {
                print(result);
                final favos =
                    await ref.read(playlistIdsNotifierProvider('favorite').future);
                final fs = FileStorage(Directory(result));
                await fs.write(
                    'listen2.back', jsonEncode({'favoriteIds': favos}));
              } else {
                // User canceled the picker
              }
            },
            child: Text('export backup')),
        Button(
            onTap: () async {
              final result = await FilePicker.platform.pickFiles();

              if (result != null) {
                print(result.paths[0]);
                final f = File(result.paths[0]!);
                final favosString = await f.readAsString();
                final favoJson =
                    jsonDecode(favosString) as Map<String, dynamic>;

                print(favoJson);
                print(favoJson["favoriteIds"]);

                List<String> favos =
                    List<String>.from(favoJson["favoriteIds"] as List);
                ref
                    .read(playlistIdsNotifierProvider('favorite').notifier)
                    .set(favos);
              } else {
                // User canceled the picker
              }
            },
            child: const Text('import backup'))
      ],
    );
  }
}
