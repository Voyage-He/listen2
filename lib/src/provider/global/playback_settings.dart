import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/storage.dart';

final autoplayOnStartupProvider =
    NotifierProvider<PlaybackSettingsNotifier, bool>(
        PlaybackSettingsNotifier.new);

class PlaybackSettingsNotifier extends Notifier<bool> {
  static const _key = 'autoplayOnStartup';

  @override
  bool build() {
    final saved = ref.watch(hiveStorageProvider).requireValue.setting.get(_key);
    return saved is bool ? saved : true;
  }

  Future<void> setAutoplay(bool enabled) async {
    await ref.read(hiveStorageProvider).requireValue.setting.put(_key, enabled);
    state = enabled;
  }
}
