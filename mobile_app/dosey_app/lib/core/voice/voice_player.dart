// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:dosey_app/core/voice/fixed_phrase_catalog.dart';
import 'package:just_audio/just_audio.dart';

enum VoicePlaybackPhase { idle, preparing, speaking }

abstract interface class VoicePlaybackGateway {
  bool get isPlaying;
  Stream<bool> get playing;

  Future<void> playAsset(String assetPath, {required double volume});
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioVoicePlaybackGateway implements VoicePlaybackGateway {
  JustAudioVoicePlaybackGateway({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  int _requestId = 0;

  @override
  bool get isPlaying =>
      _player.playing && _player.processingState != ProcessingState.completed;

  @override
  Stream<bool> get playing => _player.playerStateStream
      .map(
        (state) =>
            state.playing && state.processingState != ProcessingState.completed,
      )
      .distinct();

  @override
  Future<void> playAsset(String assetPath, {required double volume}) async {
    final requestId = ++_requestId;
    final clampedVolume = volume.clamp(0.0, 1.0).toDouble();
    await _player.setVolume(clampedVolume);
    if (requestId != _requestId) return;
    try {
      await _player.setAsset(assetPath);
    } on PlayerInterruptedException {
      if (requestId != _requestId) return;
      rethrow;
    }
    // A replacement can arrive while just_audio is still loading the asset.
    if (requestId != _requestId) return;
    await _player.play();
  }

  @override
  Future<void> stop() {
    _requestId += 1;
    return _player.stop();
  }

  @override
  Future<void> dispose() {
    _requestId += 1;
    return _player.dispose();
  }
}

class DoseyVoicePlayer {
  DoseyVoicePlayer({required VoicePlaybackGateway playbackGateway})
    : _playbackGateway = playbackGateway {
    _phase = _playbackGateway.isPlaying
        ? VoicePlaybackPhase.speaking
        : VoicePlaybackPhase.idle;
    _playingSubscription = _playbackGateway.playing.listen((isPlaying) {
      if (isPlaying) {
        _setPhase(VoicePlaybackPhase.speaking);
      } else if (_phase == VoicePlaybackPhase.speaking) {
        _setPhase(VoicePlaybackPhase.idle);
      }
    });
  }

  final VoicePlaybackGateway _playbackGateway;
  final _phaseController = StreamController<VoicePlaybackPhase>.broadcast();
  late final StreamSubscription<bool> _playingSubscription;
  int _requestId = 0;
  VoicePlaybackPhase _phase = VoicePlaybackPhase.idle;

  bool get isSpeakingNow => _playbackGateway.isPlaying;
  Stream<bool> get isSpeaking => _playbackGateway.playing;
  VoicePlaybackPhase get phase => _phase;
  Stream<VoicePlaybackPhase> get phases => _phaseController.stream;

  Future<void> speak(DoseyVoicePhrase phrase, {double volume = 1.0}) async {
    final requestId = ++_requestId;
    _setPhase(VoicePlaybackPhase.idle);
    await _playbackGateway.stop();
    if (requestId != _requestId) return;

    _setPhase(VoicePlaybackPhase.preparing);

    try {
      await _playbackGateway.playAsset(
        FixedPhraseCatalog.definitionFor(phrase).assetPath,
        volume: volume,
      );
    } finally {
      if (requestId == _requestId) {
        _setPhase(VoicePlaybackPhase.idle);
      }
    }
  }

  Future<void> stop() {
    _requestId += 1;
    _setPhase(VoicePlaybackPhase.idle);
    return _playbackGateway.stop();
  }

  Future<void> dispose() async {
    try {
      await stop();
    } finally {
      await _playingSubscription.cancel();
      try {
        await _playbackGateway.dispose();
      } finally {
        await _phaseController.close();
      }
    }
  }

  void _setPhase(VoicePlaybackPhase value) {
    if (_phase == value) return;
    _phase = value;
    _phaseController.add(value);
  }
}
