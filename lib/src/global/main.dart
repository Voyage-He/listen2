import 'package:sqflite/sqflite.dart';

import 'database/database.dart';
import './file_storage.dart';

class Globals {
  static late Database db;
  static late Storage storage;

  static Future init() async {
    
    db = await initDb();
    storage = await initStorage();
  }
}