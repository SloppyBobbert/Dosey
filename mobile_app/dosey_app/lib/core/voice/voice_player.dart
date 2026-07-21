import 'package:dosey_app/core/voice/fixed_phrase_catalog.dart';
import 'package:just_audio/just_audio.dart';

abstract interface class VoicePlaybackGateway {
  Future<void> playAsset(String assetPath);
  Future<void> dispose();
}

class JustAudioVoicePlaybackGateway implements VoicePlaybackGateway {
  JustAudioVoicePlaybackGateway({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> playAsset(String assetPath) async {
    await _player.stop();
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

  Future<void> speak(DoseyVoicePhrase phrase) {
    return _playbackGateway.playAsset(
      FixedPhraseCatalog.definitionFor(phrase).assetPath,
    );
  }

  Future<void> dispose() {
    return _playbackGateway.dispose();
  }
}
