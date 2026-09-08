import 'dart:async';

class AudioManager {
  static final AudioManager instance = AudioManager._();

  AudioManager._();

  bool musicEnabled = true;
  bool soundEnabled = true;

  final StreamController<String> _soundController =
      StreamController<String>.broadcast();

  Stream<String> get soundEvents => _soundController.stream;

  void playSound(String soundId) {
    if (!soundEnabled) return;
    _soundController.add(soundId);
  }

  void playMusic(String musicId) {
    if (!musicEnabled) return;
    _soundController.add('music:$musicId');
  }

  void stopMusic() {
    _soundController.add('music:stop');
  }

  void setSoundEnabled(bool value) {
    soundEnabled = value;
  }

  void setMusicEnabled(bool value) {
    musicEnabled = value;
  }

  void dispose() {
    _soundController.close();
  }
}
