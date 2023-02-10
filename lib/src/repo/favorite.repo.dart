import 'package:listen2/src/global/main.dart';

class FavoriteRepo {
  final _db = Globals.db;

  static final FavoriteRepo _instance = FavoriteRepo._internal();
  FavoriteRepo._internal();
  factory FavoriteRepo() => _instance;

  Future<List<String>> getAll() async {
    List<Map> favorites =  await _db.rawQuery('SELECT * FROM favorite');
    return favorites.map((e) => e['_id'] as String).toList();
  }

  Future<bool> add(String id) async {
    int resId = await _db.rawInsert('INSERT INTO favorite(_id) VALUES(\'$id\')');
    return true;
  }

  Future<bool> delete(String id) async {
    int count = await _db.rawDelete('DELETE FROM favorite WHERE _id = ?', [id]);
    return true;
  }
}