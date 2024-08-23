// import 'package:listen2/src/provider/global/database/database.dart';
// import 'package:listen2/src/provider/global/main.dart';
// import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:sqflite/sqflite.dart';

// part 'favorite.repo.g.dart';

// @riverpod
// FavoriteRepo favorite(FavoriteRepoRef ref) {
//   // app will crash if database not ready
//   var db = ref.watch(databaseNotifierProvider).requireValue;

//   return FavoriteRepo(db);
// }

// class FavoriteRepo {
//   final Database db;
//   FavoriteRepo(this.db);

//   Future<List<String>> getAll() async {
//     List<Map> favorites = await db.rawQuery('SELECT * FROM favorite');
//     return favorites.map((e) => e['_id'] as String).toList();
//   }

//   Future<bool> add(String id) async {
//     int resId = await db.rawInsert('INSERT INTO favorite(_id) VALUES(\'$id\')');
//     return true;
//   }

//   Future<bool> delete(String id) async {
//     int count = await db.rawDelete('DELETE FROM favorite WHERE _id = ?', [id]);
//     return true;
//   }
// }
