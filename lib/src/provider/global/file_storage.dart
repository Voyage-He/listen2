// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:path/path.dart';
// import 'package:path_provider/path_provider.dart';

// Future<Storage> initStorage() async {
//   Directory temp = await getTemporaryDirectory();
//   Directory doc = await getApplicationDocumentsDirectory();
  
//   return Storage(FileStorage(temp), FileStorage(doc));
// }

// class Storage {
//   FileStorage temp;
//   FileStorage doc;

//   Storage(this.temp, this.doc);
// }

// class FileStorage {
//   Directory _dir;

//   FileStorage(this._dir);

//   Future write(String path, Uint8List content) async {
//     final f = File(join(_dir.path, path));
//     if (!await f.exists()) {
//       await f.create(recursive: true);
//     }
//     await f.writeAsBytes(content);
//   }

//   Future<Uint8List> read(String path) async {
//     final f = File(join(_dir.path, path));
//     return f.readAsBytes();
//   }
// }
