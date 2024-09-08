import 'package:listen2/src/provider/global/storage.dart';
import 'package:listen2/src/provider/repo/bilibili.dart';
import 'package:listen2/src/provider/stateful/favorite.dart';
import 'package:listen2/src/provider/stateful/player.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'main.g.dart';

@riverpod
Future<void> globalReady(GlobalReadyRef ref) async {
  ref.watch(hiveStorageProvider);
  ref.watch(bilibiliClientNotifierProvider);
  ref.watch(audioHandlerProvider);
  ref.watch(favoriteIdsNotifierProvider);
  return;
}
