import 'dart:async';

import 'package:dosey_app/core/voice/fixed_phrase_catalog.dart';
import 'package:dosey_app/core/voice/voice_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('voice player routes a phrase to its WAV asset', () async {
    final gateway = _FakeVoicePlaybackGateway();
    final player = DoseyVoicePlayer(playbackGateway: gateway);

    await player.speak(DoseyVoicePhrase.missedWarning, volume: 0.45);

    expect(gateway.playedAssets, <String>[
      'assets/voice/missed_approved_warning.wav',
    ]);
    expect(gateway.lastVolume, 0.45);
  });

  test('speaking state follows actual gateway playback', () async {
    final gateway = _FakeVoicePlaybackGateway();
    final player = DoseyVoicePlayer(playbackGateway: gateway);
    final states = <bool>[];
    final subscription = player.isSpeaking.listen(states.add);

    gateway.setPlaying(true);
    await Future<void>.delayed(Duration.zero);
    gateway.setPlaying(false);
    await Future<void>.delayed(Duration.zero);

    expect(states, <bool>[true, false]);
    await subscription.cancel();
  });

  test('voice phase moves from preparing to actual speaking', () async {
    final gateway = _FakeVoicePlaybackGateway(
      blockPreparation: true,
      blockPlayback: true,
    );
    final player = DoseyVoicePlayer(playbackGateway: gateway);
    final phases = <VoicePlaybackPhase>[];
    final subscription = player.phases.listen(phases.add);

    final playback = player.speak(DoseyVoicePhrase.doseSoon);
    await Future<void>.delayed(Duration.zero);

    expect(player.phase, VoicePlaybackPhase.preparing);
    expect(phases, <VoicePlaybackPhase>[VoicePlaybackPhase.preparing]);

    gateway.completePreparation();
    await Future<void>.delayed(Duration.zero);
    gateway.setPlaying(true);
    await Future<void>.delayed(Duration.zero);

    expect(player.phase, VoicePlaybackPhase.speaking);

    gateway.setPlaying(false);
    gateway.completePlayback();
    await playback;
    await Future<void>.delayed(Duration.zero);

    expect(player.phase, VoicePlaybackPhase.idle);
    expect(phases, <VoicePlaybackPhase>[
      VoicePlaybackPhase.preparing,
      VoicePlaybackPhase.speaking,
      VoicePlaybackPhase.idle,
    ]);
    await subscription.cancel();
    await player.dispose();
  });

  test('replacement invalidates stale voice preparation', () async {
    final gateway = _FakeVoicePlaybackGateway(blockPreparation: true);
    final player = DoseyVoicePlayer(playbackGateway: gateway);

    final first = player.speak(DoseyVoicePhrase.doseSoon);
    await Future<void>.delayed(Duration.zero);
    final second = player.speak(DoseyVoicePhrase.dispensingNow);
    await Future<void>.delayed(Duration.zero);

    gateway.completePreparation();
    await Future.wait(<Future<void>>[first, second]);

    expect(player.phase, VoicePlaybackPhase.idle);
    expect(gateway.playedAssets, <String>[
      'assets/voice/reminder_dose_soon.wav',
      'assets/voice/dispense_now.wav',
    ]);
    await player.dispose();
  });

  test('a new phrase stops the phrase already playing', () async {
    final gateway = _FakeVoicePlaybackGateway(blockPlayback: true);
    final player = DoseyVoicePlayer(playbackGateway: gateway);

    final first = player.speak(DoseyVoicePhrase.doseSoon);
    await Future<void>.delayed(Duration.zero);
    final second = player.speak(DoseyVoicePhrase.dispensingNow);
    await Future<void>.delayed(Duration.zero);

    expect(gateway.stopCount, 2);
    expect(gateway.playedAssets, <String>[
      'assets/voice/reminder_dose_soon.wav',
      'assets/voice/dispense_now.wav',
    ]);

    gateway.completePlayback();
    await Future.wait(<Future<void>>[first, second]);
  });

  test('a stop failure returns the voice phase to idle', () async {
    final gateway = _FakeVoicePlaybackGateway(failStop: true);
    final player = DoseyVoicePlayer(playbackGateway: gateway);
    gateway.setPlaying(true);
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      player.speak(DoseyVoicePhrase.doseSoon),
      throwsA(isA<StateError>()),
    );

    expect(player.phase, VoicePlaybackPhase.idle);
  });

  test('dispose releases the gateway when stopping fails', () async {
    final gateway = _FakeVoicePlaybackGateway(failStop: true);
    final player = DoseyVoicePlayer(playbackGateway: gateway);

    await expectLater(player.dispose(), throwsA(isA<StateError>()));

    expect(gateway.disposeCount, 1);
  });

  test('stale asset interruption ends without starting playback', () async {
    late JustAudioVoicePlaybackGateway gateway;
    final audioPlayer = _InterruptingAudioPlayer(
      onSetAsset: () async {
        await gateway.stop();
        throw PlayerInterruptedException('replaced');
      },
    );
    gateway = JustAudioVoicePlaybackGateway(player: audioPlayer);

    await gateway.playAsset('assets/voice/test.wav', volume: 1);

    expect(audioPlayer.playCount, 0);
  });

  test('current asset interruption still reaches the caller', () async {
    final audioPlayer = _InterruptingAudioPlayer(
      onSetAsset: () async {
        throw PlayerInterruptedException('load failed');
      },
    );
    final gateway = JustAudioVoicePlaybackGateway(player: audioPlayer);

    await expectLater(
      gateway.playAsset('assets/voice/test.wav', volume: 1),
      throwsA(isA<PlayerInterruptedException>()),
    );

    expect(audioPlayer.playCount, 0);
  });
}

class _InterruptingAudioPlayer extends AudioPlayer {
  _InterruptingAudioPlayer({required this.onSetAsset});

  final Future<void> Function() onSetAsset;
  int playCount = 0;

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<Duration?> setAsset(
    String assetPath, {
    String? package,
    bool preload = true,
    Duration? initialPosition,
    dynamic tag,
  }) async {
    await onSetAsset();
    return null;
  }

  @override
  Future<void> play() async {
    playCount += 1;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeVoicePlaybackGateway implements VoicePlaybackGateway {
  _FakeVoicePlaybackGateway({
    this.blockPlayback = false,
    this.blockPreparation = false,
    this.failStop = false,
  });

  final List<String> playedAssets = <String>[];
  final StreamController<bool> _playing = StreamController<bool>.broadcast();
  final bool blockPlayback;
  final bool blockPreparation;
  final bool failStop;
  double? lastVolume;
  int disposeCount = 0;
  int stopCount = 0;
  Completer<void>? _playbackCompleter;
  Completer<void>? _preparationCompleter;

  @override
  bool get isPlaying => false;

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Future<void> dispose() async {
    disposeCount += 1;
    await _playing.close();
  }

  @override
  Future<void> playAsset(String assetPath, {required double volume}) async {
    playedAssets.add(assetPath);
    lastVolume = volume;
    if (blockPreparation) {
      _preparationCompleter ??= Completer<void>();
      await _preparationCompleter!.future;
    }
    if (blockPlayback) {
      _playbackCompleter = Completer<void>();
      await _playbackCompleter!.future;
    }
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    if (failStop) throw StateError('stop failed');
    _playbackCompleter?.complete();
    _playbackCompleter = null;
  }

  void completePlayback() {
    _playbackCompleter?.complete();
    _playbackCompleter = null;
  }

  void completePreparation() {
    _preparationCompleter?.complete();
    _preparationCompleter = null;
  }

  void setPlaying(bool value) => _playing.add(value);
}
