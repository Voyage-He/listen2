import 'package:bloc/bloc.dart';

import 'package:listen2/src/repo/track.repo.dart';
import 'package:listen2/src/repo/favorite.repo.dart';

class FavoriteCubit extends Cubit<List<Track>> {
  FavoriteRepo favoriteRepo = FavoriteRepo();
  List<String> _ids = [];
  List<Track> _favorites = [];

  FavoriteCubit() : super([]);

  Future getTracks() async {
    List<Future<Track>> futures = [];

    _ids = await favoriteRepo.getAll();
    for (final id in _ids) {
      futures.add(TrackRepo().getTrackbyId(id));
    }

    _favorites = await Future.wait(futures);
    
    emit(_favorites);
  }

  Future toggle(String id) async {
    print('toggle favo');
    if (_ids.contains(id)) {
      if (await favoriteRepo.delete(id)) {
        getTracks();
        // Or delete id in _favorites
      }
    }
    else {
      bool res = await favoriteRepo.add(id);
      if (res) {
        print('favo sucess');
        getTracks();
      }
    }
    
    await Future.delayed(Duration.zero);
  }
}