import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

class FileStorage {
  final Directory _dir;

  FileStorage(this._dir);

  Future writeBytes(String path, Uint8List content) async {
    final f = File(join(_dir.path, path));
    if (!await f.exists()) {
      await f.create(recursive: true);
    }
    await f.writeAsBytes(content);
  }

  Future write(String path, String content) async {
    final f = File(join(_dir.path, path));
    if (!await f.exists()) {
      await f.create(recursive: true);
    }
    await f.writeAsString(content);
  }

  Future<Uint8List> readBytes(String path) async {
    final f = File(join(_dir.path, path));
    return f.readAsBytes();
  }

  Future<String> read(String path) async {
    final f = File(join(_dir.path, path));
    return f.readAsString();
  }
}
