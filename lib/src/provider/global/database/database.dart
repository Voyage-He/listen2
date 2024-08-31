// import 'dart:io';
// import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// part 'database.g.dart';

// const String _tableTodo = 'favorite';

// @Riverpod(keepAlive: true)
// class DatabaseNotifier extends _$DatabaseNotifier {
//   @override
//   Future<Database> build() async {
//     return initDb();
//   }

//   Future<Database> initDb() async {
//     print("call initDB");
//     if (Platform.isWindows) {
//       sqfliteFfiInit();
//       databaseFactory = databaseFactoryFfi;
//     }
//     // String dbPath = await getDatabasesPath();
//     return await openDatabase(
//       './mydb.db',
//       version: 1,
//       onCreate: (Database db, int version) async {
//         print('create db');
//         await db.execute('''create table $_tableTodo ( _id text not null)''');
//       },
//       onOpen: (Database db) async {
//         print('open db');
//         List<Map> favoriteCount =
//             await db.rawQuery('SELECT COUNT(*) FROM $_tableTodo');
//         if (favoriteCount[0]['COUNT(*)'] == 0) {
//           var id = await db
//               .rawInsert('INSERT INTO $_tableTodo(_id) VALUES(\'1aE411n7wb\')');
//         }
//       },
//     );
//   }
// }
