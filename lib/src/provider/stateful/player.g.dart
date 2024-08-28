// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioHandlerHash() => r'cb8aacca62210befca61d0ebd6e902c743666f13';

/// See also [audioHandler].
@ProviderFor(audioHandler)
final audioHandlerProvider = AutoDisposeFutureProvider<AudioHandler>.internal(
  audioHandler,
  name: r'audioHandlerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$audioHandlerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AudioHandlerRef = AutoDisposeFutureProviderRef<AudioHandler>;
String _$playerStateNotifierHash() =>
    r'a1415419c9ab400ef70cd8ce8c1444e5d8f8bed5';

/// See also [PlayerStateNotifier].
@ProviderFor(PlayerStateNotifier)
final playerStateNotifierProvider =
    AutoDisposeNotifierProvider<PlayerStateNotifier, PlayerState>.internal(
  PlayerStateNotifier.new,
  name: r'playerStateNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$playerStateNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PlayerStateNotifier = AutoDisposeNotifier<PlayerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
