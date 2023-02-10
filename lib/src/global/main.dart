import 'package:sqflite/sqflite.dart';

import 'database/database.dart';

class Globals {
  static late Database db;

  static Future init() async {
    
    db = await createDb();
  }
}