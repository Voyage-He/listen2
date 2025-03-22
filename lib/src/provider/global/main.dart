import 'package:listen2/src/provider/global/current_playlist.dart';
import 'package:listen2/src/provider/global/player.dart';
import 'package:listen2/src/provider/global/storage.dart';
import 'package:listen2/src/provider/repo/bilibili.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'main.g.dart';

@riverpod
Future<void> globalReady(GlobalReadyRef ref) async {
  await Future.wait([
    ref.watch(hiveStorageProvider.future),
    ref.watch(bilibiliClientNotifierProvider.future),
    ref.watch(audioHandlerProvider.future) // android player initization
  ]);
  ref.listen(currentPlaylistNotifierProvider.notifier, (_, __){});
  return;
}
