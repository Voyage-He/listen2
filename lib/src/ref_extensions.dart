import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/storage.dart';
import 'package:listen2/src/provider/global/player.dart';

extension RefExtension on Ref {
  T? watchSolvedFuture<T>(FutureProvider<T> provider) {
    return watch(provider).valueOrNull;
  }

  Storage get storage => watchSolvedFuture(hiveStorageProvider)!;
  PlayerState get playerState => watch(playerStateNotifierProvider);
}

extension WidgetRefExtension on WidgetRef {
  T? watchSolvedFuture<T>(FutureProvider<T> provider) {
    return watch(provider).valueOrNull;
  }

  Storage get storage => watchSolvedFuture(hiveStorageProvider)!;
  PlayerState get playerState => watch(playerStateNotifierProvider);
}
