import 'package:sqflite/sqflite.dart';

const String _tableTodo = 'favorite';

Future<Database> createDb() async {
  // String dbPath = await getDatabasesPath();
  return await openDatabase(
    'mydb.db',
    version: 1,
    onCreate: (Database db, int version) async {
      print('create db');
      await db.execute('''create table $_tableTodo ( _id text not null)''');
    },
    onOpen: (Database db) async {
      print('open db');
      List<Map> a = await db.rawQuery('SELECT COUNT(*) FROM $_tableTodo');
      if (a[0]['COUNT(*)'] == 0) {
        var id = await db.rawInsert('INSERT INTO $_tableTodo(_id) VALUES(\'1aE411n7wb\')');
      }
    },
  );
    
}