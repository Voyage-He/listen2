import 'dart:io';
import 'package:listen2/src/provider/global/storage.dart';
import 'package:music_api/music_api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

part 'bilibili.g.dart';

@Riverpod(keepAlive: true)
class BilibiliClientNotifier extends _$BilibiliClientNotifier {
  @override
  Future<BilibiliClient> build() async {
    // try {
    print("test================");
    var value = (await ref.watch(hiveStorageProvider.future)).value;
    var client = BilibiliClient(value);
    await client.init();
    print("bili client inited");
    return client;
    // } catch (e, a) {
    //   print(e);
    //   print(a);
    //   throw (e, a);
    // }
  }
}
