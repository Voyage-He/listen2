import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../global/track/Track.data.dart';

final keywordProvd = StateProvider<String>((ref) => '');

final searchResultProvd = StateNotifierProvider<SearchResultNotifier, List<Track>>((ref) => SearchResultNotifier(ref));

class SearchResultNotifier extends StateNotifier<List<Track>> {
  final Ref ref;

  SearchResultNotifier(this.ref) :
    
    super([]);

  Future<void> search() async {
    final keyword = ref.read(keywordProvd);
    if (keyword.isEmpty) return;
    if (!trackRpstr.client.hasCookie) return;
    var tracks = await trackRpstr.search(keyword);
    state = tracks;
  }
}