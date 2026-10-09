import 'dart:convert';
import 'dart:typed_data';

/// Keeps the existing listen2.back format compatible with Android backups.
class PlaylistBackup {
  static Uint8List encode(List<String> favoriteIds) =>
      Uint8List.fromList(utf8.encode(jsonEncode({'favoriteIds': favoriteIds})));

  static List<String> decode(List<int> bytes) {
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, dynamic> || data['favoriteIds'] is! List) {
      throw const FormatException('Invalid listen2 backup');
    }
    final ids = data['favoriteIds'] as List;
    if (ids.any((id) => id is! String || id.trim().isEmpty)) {
      throw const FormatException('Invalid favorite IDs');
    }
    return List<String>.from(ids);
  }
}
