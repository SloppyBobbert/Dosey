// ignore_for_file: prefer_initializing_formals

import 'package:dosey_app/core/voice/fixed_phrase_catalog.dart';
import 'package:just_audio/just_audio.dart';

abstract interface class VoicePlaybackGateway {
  Future<void> playAsset(String assetPath, {required double volume});
  Future<void> dispose();
}

class JustAudioVoicePlaybackGateway implements VoicePlaybackGateway {
  JustAudioVoicePlaybackGateway({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  Future<void> _playbackQueue = Future<void>.value();

  @override
  Future<void> playAsset(String assetPath, {required double volume}) async {
    final clampedVolume = volume.clamp(0.0, 1.0).toDouble();
    final playbackFuture = _playbackQueue.then((_) async {
      await _player.stop();
      await _player.setVolume(clampedVolume);
      await _player.setAsset(assetPath);
      await _player.play();
    });
    _playbackQueue = playbackFuture.catchError((_) {});
    await playbackFuture;
  }

  @override
  Future<void> dispose() {
    return _player.dispose();
  }
}

class DoseyVoicePlayer {
  DoseyVoicePlayer({required VoicePlaybackGateway playbackGateway})
    : _playbackGateway = playbackGateway;

  final VoicePlaybackGateway _playbackGateway;

  Future<void> speak(DoseyVoicePhrase phrase, {double volume = 1.0}) {
    return _playbackGateway.playAsset(
      FixedPhraseCatalog.definitionFor(phrase).assetPath,
      volume: volume,
    );
  }

  Future<void> dispose() {
    return _playbackGateway.dispose();
  }
}
