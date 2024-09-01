// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioHandlerHash() => r'4e97273c6f8f19d1c19f95e664fe35a690c7781e';

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
    r'57ec94e041ff1fdc112fa9af50c8c6cfdb200c60';

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
