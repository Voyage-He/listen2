import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/storage.dart';

final playerHintsProvider =
    NotifierProvider<PlayerHintsNotifier, Set<String>>(PlayerHintsNotifier.new);

class PlayerHintsNotifier extends Notifier<Set<String>> {
  static const storageKey = 'playerUxHintsV1';

  @override
  Set<String> build() {
    final saved =
        ref.watch(hiveStorageProvider).valueOrNull?.setting.get(storageKey);
    return saved is List ? saved.whereType<String>().toSet() : <String>{};
  }

  Future<void> markSeen(String hint) async {
    if (state.contains(hint)) return;
    state = {...state, hint};
    final setting = ref.read(hiveStorageProvider).valueOrNull?.setting;
    if (setting != null) await setting.put(storageKey, state.toList());
  }
}
