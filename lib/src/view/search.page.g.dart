// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search.page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tracksAndIsFaviriteHash() =>
    r'e9c794f1d2bcecb42ef164e03b3d0fece5ff8f3b';

/// See also [tracksAndIsFavirite].
@ProviderFor(tracksAndIsFavirite)
final tracksAndIsFaviriteProvider =
    AutoDisposeFutureProvider<Map<String, dynamic>>.internal(
  tracksAndIsFavirite,
  name: r'tracksAndIsFaviriteProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$tracksAndIsFaviriteHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TracksAndIsFaviriteRef
    = AutoDisposeFutureProviderRef<Map<String, dynamic>>;
String _$keywordNotifierHash() => r'd5d7dbedf0aa1b8289720d54878f2590556bc312';

/// See also [KeywordNotifier].
@ProviderFor(KeywordNotifier)
final keywordNotifierProvider =
    AutoDisposeNotifierProvider<KeywordNotifier, String>.internal(
  KeywordNotifier.new,
  name: r'keywordNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$keywordNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$KeywordNotifier = AutoDisposeNotifier<String>;
String _$searchResultHash() => r'674cd11f00e8c80c7a45814185682fe2d1d29a57';

/// See also [SearchResult].
@ProviderFor(SearchResult)
final searchResultProvider =
    AutoDisposeAsyncNotifierProvider<SearchResult, List<Track>>.internal(
  SearchResult.new,
  name: r'searchResultProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$searchResultHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SearchResult = AutoDisposeAsyncNotifier<List<Track>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
