import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:listen2/src/provider/global/background_settings.dart';
import 'package:listen2/src/provider/global/storage.dart';

void main() {
  late Directory directory;
  late Storage storage;
  late ProviderContainer container;
  ProviderContainer createContainer() => ProviderContainer(overrides: [
        hiveStorageProvider.overrideWith((ref) async => storage),
      ]);

  setUp(() async {
    directory =
        await Directory.systemTemp.createTemp('listen2-background-test-');
    Hive.init(directory.path);
    final setting = await Hive.openBox('setting');
    storage =
        Storage(setting, setting, await Hive.openBox<Uint8List>('binary'), {});
    container = createContainer();
    await container.read(hiveStorageProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('defaults keep the existing background and edits survive a restart',
      () async {
    final defaults = container.read(backgroundSettingsProvider);
    expect(defaults.blur, 32);
    expect(defaults.gradient, .6);
    final settings = container.read(backgroundSettingsProvider.notifier);
    settings.setBlur(48);
    settings.setGradient(.25);
    await settings.save();
    container.dispose();
    container = createContainer();
    await container.read(hiveStorageProvider.future);
    final restored = container.read(backgroundSettingsProvider);
    expect(restored.blur, 48);
    expect(restored.gradient, .25);
  });

  test('out of range and malformed saved values stay within slider limits',
      () async {
    await storage.setting
        .put('playerBackgroundAppearance', {'blur': 999, 'gradient': -1});
    final settings = container.read(backgroundSettingsProvider);
    expect(settings.blur, BackgroundSettings.maxBlur);
    expect(settings.gradient, 0);
    await storage.setting.put('playerBackgroundAppearance',
        {'blur': 'invalid', 'gradient': double.nan});
    container.invalidate(backgroundSettingsProvider);
    final restored = container.read(backgroundSettingsProvider);
    expect(restored.blur, 32);
    expect(restored.gradient, .6);
  });
}
