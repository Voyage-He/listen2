import 'package:listen2/src/provider/global/storage.dart';
import 'package:listen2/src/ref_extensions.dart';
import 'package:music_api/music_api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bilibili.g.dart';

@Riverpod(keepAlive: true)
class BilibiliClientNotifier extends _$BilibiliClientNotifier {
  @override
  Future<BilibiliClient> build() async {
    // try {
    var storage = ref.watchSolvedFuture(hiveStorageProvider);
    var client = BilibiliClient(storage!.value);
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
