import 'package:listen2/src/provider/global/storage.dart';
import 'package:listen2/src/provider/repo/bilibili.dart';
import 'package:listen2/src/provider/stateful/favorite.dart';
import 'package:listen2/src/provider/stateful/player.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'main.g.dart';

@riverpod
Future<void> globalReady(GlobalReadyRef ref) async {
  await ref.watch(hiveStorageProvider.future);
  await ref.watch(bilibiliClientNotifierProvider.future);
  await ref.watch(audioHandlerProvider.future);
  await ref.watch(favoriteIdsNotifierProvider.future);
  return;
}
