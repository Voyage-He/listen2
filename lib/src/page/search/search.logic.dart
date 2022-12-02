import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../global/track/Track.data.dart';

final searchResultProvd = StateNotifierProvider<SearchResultNotifier, List<Track>>((ref) => SearchResultNotifier());

class SearchResultNotifier extends StateNotifier<List<Track>> {
  SearchResultNotifier() :
    
    super([]){var x = trackRpstr;}

  Future<void> search(keyword) async {
    var tracks = await trackRpstr.search(keyword);
    state = tracks;
  }
}