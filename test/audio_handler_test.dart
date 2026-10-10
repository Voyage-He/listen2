import 'package:audio_service/audio_service.dart'
    show MediaControl, MediaItem, AudioProcessingState;
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen2/src/provider/global/player.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const playerChannel = MethodChannel('xyz.luan/audioplayers');
  const sessionChannel = MethodChannel('com.ryanheise.audio_session');
  const codec = StandardMethodCodec();
  late AudioHandler handler;
  late List<MethodCall> calls;

  void emit(String event, [Object? value]) {
    binding.channelBuffers.push(
      'xyz.luan/audioplayers/events/${handler.player.playerId}',
      codec.encodeSuccessEnvelope({'event': event, 'value': value}),
      (_) {},
    );
  }

  setUp(() async {
    calls = [];
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(sessionChannel, (_) async => null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(playerChannel,
        (call) async {
      calls.add(call);
      if (call.method == 'create') {
        final id = (call.arguments as Map)['playerId'];
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null);
      }
      if (call.method == 'setSourceUrl') emit('audio.onPrepared', true);
      return null;
    });
    handler = AudioHandler();
    await handler.initialize();
  });

  tearDown(() async {
    await handler.dispose();
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(playerChannel, null);
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(sessionChannel, null);
  });

  test('system controls operate the player and update Now Playing state',
      () async {
    await handler.player.setSource(ap.DeviceFileSource('/cache/song.m4a'));
    await handler.play();
    await Future<void>.delayed(Duration.zero);
    expect(calls.last.method, 'resume');
    expect(handler.playbackState.value.playing, isTrue);
    expect(handler.playbackState.value.controls.first, MediaControl.pause);

    await handler.pause();
    await Future<void>.delayed(Duration.zero);
    expect(calls.last.method, 'pause');
    expect(handler.playbackState.value.playing, isFalse);
    expect(handler.playbackState.value.controls.first, MediaControl.play);

    await handler.seek(const Duration(seconds: 15));
    expect(calls.last.method, 'seek');
    expect(handler.playbackState.value.updatePosition,
        const Duration(seconds: 15));
    await handler.stop();
    await Future<void>.delayed(Duration.zero);
    expect(
        handler.playbackState.value.processingState, AudioProcessingState.idle);
  });

  test('mounting a record with the needle raised never starts audio', () async {
    await handler.load(ap.DeviceFileSource('/cache/song.m4a'), autoplay: false);
    expect(calls.where((call) => call.method == 'resume'), isEmpty);
    expect(handler.player.source, isNotNull);
    expect(handler.playbackState.value.playing, isFalse);
    expect(handler.player.state, ap.PlayerState.paused);
    await handler.play();
    await Future<void>.delayed(Duration.zero);
    expect(calls.last.method, 'resume');
    expect(handler.playbackState.value.playing, isTrue);
  });

  test('native duration and position reach lock screen metadata', () async {
    handler.mediaItem.add(const MediaItem(id: 'song', title: 'Song'));
    emit('audio.onDuration', 90000);
    emit('audio.onCurrentPosition', 12000);
    await Future<void>.delayed(Duration.zero);
    expect(handler.mediaItem.value!.duration, const Duration(seconds: 90));
    expect(handler.playbackState.value.updatePosition,
        const Duration(seconds: 12));
  });

  test('completed tracks cannot be resumed with no source', () async {
    await handler.player.setSource(ap.DeviceFileSource('/cache/song.m4a'));
    emit('audio.onComplete');
    await Future<void>.delayed(Duration.zero);
    final count = calls.where((call) => call.method == 'resume').length;
    await handler.play();
    expect(calls.where((call) => call.method == 'resume').length, count);
    expect(handler.playbackState.value.processingState,
        AudioProcessingState.completed);
  });
}
