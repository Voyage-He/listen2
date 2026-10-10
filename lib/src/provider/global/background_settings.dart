import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/global/storage.dart';

class BackgroundSettings {
  const BackgroundSettings({this.blur = 32, this.gradient = .6});
  static const maxBlur = 64.0;
  final double blur;
  final double gradient;

  BackgroundSettings copyWith({double? blur, double? gradient}) =>
      BackgroundSettings(
          blur: blur?.clamp(0, maxBlur).toDouble() ?? this.blur,
          gradient: gradient?.clamp(0, 1).toDouble() ?? this.gradient);
}

final backgroundSettingsProvider =
    NotifierProvider<BackgroundSettingsNotifier, BackgroundSettings>(
        BackgroundSettingsNotifier.new);

class BackgroundSettingsNotifier extends Notifier<BackgroundSettings> {
  static const _key = 'playerBackgroundAppearance';

  @override
  BackgroundSettings build() {
    final saved = ref.watch(hiveStorageProvider).requireValue.setting.get(_key);
    if (saved is! Map) return const BackgroundSettings();
    double value(String key, double fallback, double max) {
      final entry = saved[key];
      return entry is num && entry.isFinite
          ? entry.clamp(0, max).toDouble()
          : fallback;
    }

    return BackgroundSettings(
        blur: value('blur', 32, BackgroundSettings.maxBlur),
        gradient: value('gradient', .6, 1));
  }

  void setBlur(double value) => state = state.copyWith(blur: value);
  void setGradient(double value) => state = state.copyWith(gradient: value);

  Future<void> save() => ref
      .read(hiveStorageProvider)
      .requireValue
      .setting
      .put(_key, {'blur': state.blur, 'gradient': state.gradient});
}
