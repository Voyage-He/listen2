// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrackAdapter extends TypeAdapter<Track> {
  @override
  final int typeId = 1;

  @override
  Track read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Track(
      fields[0] as String,
      fields[1] as String,
      fields[2] as String,
      fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Track obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.bvid)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.singer)
      ..writeByte(3)
      ..write(obj.pictureUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$trackHash() => r'ac3ae9a370fd81819b8113f589e11a547c4f0fde';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [track].
@ProviderFor(track)
const trackProvider = TrackFamily();

/// See also [track].
class TrackFamily extends Family<AsyncValue<Track>> {
  /// See also [track].
  const TrackFamily();

  /// See also [track].
  TrackProvider call(
    String id,
  ) {
    return TrackProvider(
      id,
    );
  }

  @override
  TrackProvider getProviderOverride(
    covariant TrackProvider provider,
  ) {
    return call(
      provider.id,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'trackProvider';
}

/// See also [track].
class TrackProvider extends AutoDisposeFutureProvider<Track> {
  /// See also [track].
  TrackProvider(
    String id,
  ) : this._internal(
          (ref) => track(
            ref as TrackRef,
            id,
          ),
          from: trackProvider,
          name: r'trackProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$trackHash,
          dependencies: TrackFamily._dependencies,
          allTransitiveDependencies: TrackFamily._allTransitiveDependencies,
          id: id,
        );

  TrackProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<Track> Function(TrackRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TrackProvider._internal(
        (ref) => create(ref as TrackRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Track> createElement() {
    return _TrackProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TrackProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin TrackRef on AutoDisposeFutureProviderRef<Track> {
  /// The parameter `id` of this provider.
  String get id;
}

class _TrackProviderElement extends AutoDisposeFutureProviderElement<Track>
    with TrackRef {
  _TrackProviderElement(super.provider);

  @override
  String get id => (origin as TrackProvider).id;
}

String _$trackBytesHash() => r'5ed6d5645416feef288fd6124e3260513fe4e453';

/// See also [trackBytes].
@ProviderFor(trackBytes)
const trackBytesProvider = TrackBytesFamily();

/// See also [trackBytes].
class TrackBytesFamily extends Family<AsyncValue<Uint8List>> {
  /// See also [trackBytes].
  const TrackBytesFamily();

  /// See also [trackBytes].
  TrackBytesProvider call(
    Track track,
  ) {
    return TrackBytesProvider(
      track,
    );
  }

  @override
  TrackBytesProvider getProviderOverride(
    covariant TrackBytesProvider provider,
  ) {
    return call(
      provider.track,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'trackBytesProvider';
}

/// See also [trackBytes].
class TrackBytesProvider extends AutoDisposeFutureProvider<Uint8List> {
  /// See also [trackBytes].
  TrackBytesProvider(
    Track track,
  ) : this._internal(
          (ref) => trackBytes(
            ref as TrackBytesRef,
            track,
          ),
          from: trackBytesProvider,
          name: r'trackBytesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$trackBytesHash,
          dependencies: TrackBytesFamily._dependencies,
          allTransitiveDependencies:
              TrackBytesFamily._allTransitiveDependencies,
          track: track,
        );

  TrackBytesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.track,
  }) : super.internal();

  final Track track;

  @override
  Override overrideWith(
    FutureOr<Uint8List> Function(TrackBytesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TrackBytesProvider._internal(
        (ref) => create(ref as TrackBytesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        track: track,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Uint8List> createElement() {
    return _TrackBytesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TrackBytesProvider && other.track == track;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, track.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin TrackBytesRef on AutoDisposeFutureProviderRef<Uint8List> {
  /// The parameter `track` of this provider.
  Track get track;
}

class _TrackBytesProviderElement
    extends AutoDisposeFutureProviderElement<Uint8List> with TrackBytesRef {
  _TrackBytesProviderElement(super.provider);

  @override
  Track get track => (origin as TrackBytesProvider).track;
}

String _$trackCoverHash() => r'6efb2c840b8453b330a7cf7cdc369343df2ca83b';

/// See also [trackCover].
@ProviderFor(trackCover)
const trackCoverProvider = TrackCoverFamily();

/// See also [trackCover].
class TrackCoverFamily extends Family<AsyncValue<Uint8List>> {
  /// See also [trackCover].
  const TrackCoverFamily();

  /// See also [trackCover].
  TrackCoverProvider call(
    Track track,
  ) {
    return TrackCoverProvider(
      track,
    );
  }

  @override
  TrackCoverProvider getProviderOverride(
    covariant TrackCoverProvider provider,
  ) {
    return call(
      provider.track,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'trackCoverProvider';
}

/// See also [trackCover].
class TrackCoverProvider extends AutoDisposeFutureProvider<Uint8List> {
  /// See also [trackCover].
  TrackCoverProvider(
    Track track,
  ) : this._internal(
          (ref) => trackCover(
            ref as TrackCoverRef,
            track,
          ),
          from: trackCoverProvider,
          name: r'trackCoverProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$trackCoverHash,
          dependencies: TrackCoverFamily._dependencies,
          allTransitiveDependencies:
              TrackCoverFamily._allTransitiveDependencies,
          track: track,
        );

  TrackCoverProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.track,
  }) : super.internal();

  final Track track;

  @override
  Override overrideWith(
    FutureOr<Uint8List> Function(TrackCoverRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TrackCoverProvider._internal(
        (ref) => create(ref as TrackCoverRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        track: track,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Uint8List> createElement() {
    return _TrackCoverProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TrackCoverProvider && other.track == track;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, track.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin TrackCoverRef on AutoDisposeFutureProviderRef<Uint8List> {
  /// The parameter `track` of this provider.
  Track get track;
}

class _TrackCoverProviderElement
    extends AutoDisposeFutureProviderElement<Uint8List> with TrackCoverRef {
  _TrackCoverProviderElement(super.provider);

  @override
  Track get track => (origin as TrackCoverProvider).track;
}

String _$currentTrackHash() => r'462c234284cab31c4e57424550431abc8d8742c3';

/// See also [CurrentTrack].
@ProviderFor(CurrentTrack)
final currentTrackProvider = NotifierProvider<CurrentTrack, Track?>.internal(
  CurrentTrack.new,
  name: r'currentTrackProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentTrackHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentTrack = Notifier<Track?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
