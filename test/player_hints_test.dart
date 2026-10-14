import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:listen2/src/provider/global/player_hints.dart';
import 'package:listen2/src/provider/global/storage.dart';

void main() {
  late Directory directory;
  late Storage storage;
  late ProviderContainer container;
  ProviderContainer createContainer() => ProviderContainer(overrides: [
        hiveStorageProvider.overrideWith((ref) async => storage),
      ]);
  Future<Storage> openStorage() async {
    final setting = await Hive.openBox('setting');
    return Storage(
        setting, setting, await Hive.openBox<Uint8List>('binary'), {});
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('listen2-hints-test-');
    Hive.init(directory.path);
    storage = await openStorage();
    container = createContainer();
    await container.read(hiveStorageProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test('learned hints are remembered after reopening storage', () async {
    expect(container.read(playerHintsProvider), isEmpty);
    await container.read(playerHintsProvider.notifier).markSeen('arm');
    await container.read(playerHintsProvider.notifier).markSeen('grooves');
    container.dispose();
    await Hive.close();
    storage = await openStorage();
    container = createContainer();
    await container.read(hiveStorageProvider.future);
    expect(container.read(playerHintsProvider), {'arm', 'grooves'});
  });
  test('invalid preference data does not suppress every hint', () async {
    await storage.setting.put(PlayerHintsNotifier.storageKey, ['arm', 42]);
    expect(container.read(playerHintsProvider), {'arm'});
    await container.read(playerHintsProvider.notifier).markSeen('queue');
    expect(
        storage.setting.get(PlayerHintsNotifier.storageKey), ['arm', 'queue']);
  });
}
