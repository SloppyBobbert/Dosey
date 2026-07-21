import 'package:dosey_app/core/voice/fixed_phrase_catalog.dart';
import 'package:dosey_app/core/voice/voice_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voice player routes a phrase to its WAV asset', () async {
    final gateway = _FakeVoicePlaybackGateway();
    final player = DoseyVoicePlayer(playbackGateway: gateway);

    await player.speak(DoseyVoicePhrase.missedWarning);

    expect(gateway.playedAssets, <String>[
      'assets/voice/missed_approved_warning.wav',
    ]);
  });
}

class _FakeVoicePlaybackGateway implements VoicePlaybackGateway {
  final List<String> playedAssets = <String>[];

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playAsset(String assetPath) async {
    playedAssets.add(assetPath);
  }
}
