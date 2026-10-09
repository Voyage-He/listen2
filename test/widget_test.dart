import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:listen2/src/playlist_backup.dart';

void main() {
  test('imports the existing Android backup format without changing order', () {
    final bytes =
        utf8.encode('{"favoriteIds":["1aE411n7wb","中文", "1yA4y197qE"]}');
    expect(PlaylistBackup.decode(bytes), ['1aE411n7wb', '中文', '1yA4y197qE']);
  });

  test('export can be imported, including an empty playlist', () {
    for (final ids in <List<String>>[
      [],
      ['1aE411n7wb', '中文']
    ]) {
      expect(PlaylistBackup.decode(PlaylistBackup.encode(ids)), ids);
    }
  });

  test('rejects malformed backups before replacing favorites', () {
    for (final content in [
      'not json',
      '[]',
      '{}',
      '{"favoriteIds":"wrong"}',
      '{"favoriteIds":[1]}',
      '{"favoriteIds":[null]}',
      '{"favoriteIds":[" "]}',
    ]) {
      expect(() => PlaylistBackup.decode(utf8.encode(content)),
          throwsFormatException);
    }
  });
}
