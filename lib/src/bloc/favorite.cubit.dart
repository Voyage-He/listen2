// import 'package:bloc/bloc.dart';

// import 'package:listen2/src/provider/repo/track.repo.dart';
// import 'package:listen2/src/provider/repo/favorite.repo.dart';
// import 'package:riverpod_annotation/riverpod_annotation.dart';

// @riverpod
// @riverpod
// class FavoriteNotifier extends _$FavoriteNotifier {
//   @override
//   Future<List<Track>> build() {
//     return;
//   }
// }

// class FavoriteCubit extends Cubit<List<Track>> {
//   FavoriteRepo favoriteRepo = FavoriteRepo();
//   List<String> _ids = [];
//   List<Track> _favorites = [];

//   FavoriteCubit() : super([]);

//   Future getTracks() async {
//     List<Future<Track>> futures = [];

//     _ids = await favoriteRepo.getAll();
//     for (final id in _ids) {
//       futures.add(TrackRepo().getTrackbyId(id));
//     }

//     _favorites = await Future.wait(futures);

//     emit(_favorites);
//   }

//   Future toggle(String id) async {
//     print('toggle favo');
//     if (_ids.contains(id)) {
//       if (await favoriteRepo.delete(id)) {
//         getTracks();
//         // Or delete id in _favorites
//       }
//     } else {
//       bool res = await favoriteRepo.add(id);
//       if (res) {
//         print('favo sucess');
//         getTracks();
//       }
//     }

//     await Future.delayed(Duration.zero);
//   }
// }
