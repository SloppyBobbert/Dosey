import 'package:dosey_app/core/voice/fixed_phrase_catalog.dart';
import 'package:dosey_app/core/voice/voice_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voice player routes a phrase to its WAV asset', () async {
    final gateway = _FakeVoicePlaybackGateway();
    final player = DoseyVoicePlayer(playbackGateway: gateway);

    await player.speak(DoseyVoicePhrase.missedWarning, volume: 0.45);

    expect(gateway.playedAssets, <String>[
      'assets/voice/missed_approved_warning.wav',
    ]);
    expect(gateway.lastVolume, 0.45);
  });
}

class _FakeVoicePlaybackGateway implements VoicePlaybackGateway {
  final List<String> playedAssets = <String>[];
  double? lastVolume;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playAsset(String assetPath, {required double volume}) async {
    playedAssets.add(assetPath);
    lastVolume = volume;
  }
}
