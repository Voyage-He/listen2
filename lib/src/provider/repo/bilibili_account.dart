import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:music_api/music_api.dart';

class _SecureSessionStore implements BilibiliSessionStore {
  static const _key = 'bilibili_login_session';
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String session) =>
      _storage.write(key: _key, value: session);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

final bilibiliAccountClientProvider = Provider<BilibiliAccountClient>((ref) {
  final client = BilibiliAccountClient(_SecureSessionStore());
  ref.onDispose(client.close);
  return client;
});

final bilibiliAccountProvider =
    AsyncNotifierProvider<BilibiliAccount, BilibiliUser?>(BilibiliAccount.new);

class BilibiliAccount extends AsyncNotifier<BilibiliUser?> {
  BilibiliAccountClient get _client => ref.read(bilibiliAccountClientProvider);
  @override
  Future<BilibiliUser?> build() => _client.getLoggedInUser();

  Future<BilibiliQrStatus> poll(String key) async {
    final status = await _client.pollQrCode(key);
    if (status == BilibiliQrStatus.confirmed) state = AsyncData(_client.user);
    return status;
  }

  Future<void> logout() async {
    try {
      await _client.logout();
    } finally {
      state = AsyncData(_client.user);
    }
  }

  void sessionExpired() => state = const AsyncData(null);
}
