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

  @override
  Future<void> playAsset(String assetPath, {required double volume}) async {
    await _player.stop();
    await _player.setVolume(volume.clamp(0.0, 1.4));
    await _player.setAsset(assetPath);
    await _player.play();
  }

  @override
  Future<void> dispose() {
    return _player.dispose();
  }
}

class DoseyVoicePlayer {
  DoseyVoicePlayer({required this._playbackGateway});

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
