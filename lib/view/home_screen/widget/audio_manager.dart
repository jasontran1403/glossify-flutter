import 'package:just_audio/just_audio.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  late AudioPlayer _player;
  bool _isInitialized = false;
  bool _isMuted = false;

  bool get isPlaying => _isInitialized && _player.playing;
  bool get isMuted => _isMuted;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _player = AudioPlayer();

    try {
      await _player.setAsset('assets/audio/dashboard-theme.mp3');

      await _player.setLoopMode(LoopMode.one);

      await _player.setVolume(0.8);

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
    }
  }

  Future<void> play() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (!_player.playing) {
        await _player.play();
      }
    } catch (e) {
      print('AudioManager: ❌ Error playing - $e');
    }
  }

  Future<void> pause() async {
    if (_isInitialized && _player.playing) {
      await _player.pause();
    }
  }

  Future<void> resume() async {
    if (_isInitialized && !_player.playing) {
      await _player.play();
    }
  }

  Future<void> stop() async {
    if (_isInitialized) {
      await _player.stop();
      await _player.seek(Duration.zero);
    }
  }

  Future<void> mute() async {
    if (_isInitialized) {
      await _player.setVolume(0.0);
      _isMuted = true;
    }
  }

  Future<void> unmute() async {
    if (_isInitialized) {
      await _player.setVolume(1.0);
      _isMuted = false;
    }
  }

  Future<void> toggleMute() async {
    if (_isMuted) {
      await unmute();
    } else {
      await mute();
    }
  }

  Future<void> setVolume(double volume) async {
    if (_isInitialized) {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _player.setVolume(clampedVolume);
      _isMuted = clampedVolume == 0.0;
    }
  }

  double getVolume() {
    if (_isInitialized) {
      return _player.volume;
    }
    return 0.0;
  }

  Future<void> fadeOut({Duration duration = const Duration(seconds: 2)}) async {
    if (!_isInitialized) return;

    const steps = 20;
    final stepDuration = duration.inMilliseconds ~/ steps;
    final currentVolume = _player.volume;

    for (int i = steps; i >= 0; i--) {
      final volume = currentVolume * (i / steps);
      await setVolume(volume);
      await Future.delayed(Duration(milliseconds: stepDuration));
    }
  }

  Future<void> fadeIn({Duration duration = const Duration(seconds: 2)}) async {
    if (!_isInitialized) return;

    const steps = 20;
    final stepDuration = duration.inMilliseconds ~/ steps;

    for (int i = 0; i <= steps; i++) {
      final volume = i / steps;
      await setVolume(volume);
      await Future.delayed(Duration(milliseconds: stepDuration));
    }
  }

  Future<void> seek(Duration position) async {
    if (_isInitialized) {
      await _player.seek(position);
    }
  }

  Duration? getCurrentPosition() {
    if (_isInitialized) {
      return _player.position;
    }
    return null;
  }

  Duration? getDuration() {
    if (_isInitialized) {
      return _player.duration;
    }
    return null;
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await _player.dispose();
      _isInitialized = false;
    }
  }
}