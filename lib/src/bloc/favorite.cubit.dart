import 'package:listen2/src/repo/favorite.repo.dart';
import 'package:bloc/bloc.dart';

import '../repo/track.repo.dart';

class FavoriteCubit extends Cubit<List<String>> {
  FavoriteRepo favoriteRepo = FavoriteRepo();
  List<String> _favorites = [];

  FavoriteCubit() : super([]);

  Future getTracks() async {
    _favorites = await favoriteRepo.getAll();
    emit(_favorites);
  }

  Future toggle(String id) async {
    print('toggle favo');
    if (_favorites.contains(id)) {
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

class TrackCubit extends Cubit<Track?> {
  TrackRepo trackRepo;

  TrackCubit(this.trackRepo) : super(null);

  void getTrackbyId(String id) async {

    var track = await trackRepo.getTrackbyId(id);

    emit(track);
  }
}