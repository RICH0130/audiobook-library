import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum PlayerState { stopped, playing, paused }

/// Reads a chapter sentence by sentence and reports which sentence (and which
/// characters inside it) is being spoken, so the UI can highlight in sync.
class TtsPlayer extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  List<String> _sentences = const [];
  int currentIndex = 0;
  int wordStart = -1;
  int wordEnd = -1;
  PlayerState state = PlayerState.stopped;

  /// Called when the last sentence of the chapter finishes.
  VoidCallback? onChapterFinished;

  /// Called whenever the spoken sentence changes (for saving progress).
  void Function(int index)? onSentenceChanged;

  int _session = 0;

  TtsPlayer() {
    _tts.setProgressHandler((text, start, end, word) {
      wordStart = start;
      wordEnd = end;
      notifyListeners();
    });
    _tts.awaitSpeakCompletion(true);
  }

  Future<void> configure({
    required String language,
    required double rate,
    required double pitch,
  }) async {
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setSharedInstance(true);
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [IosTextToSpeechAudioCategoryOptions.duckOthers],
    );
  }

  Future<List<String>> availableLanguages() async {
    final langs = await _tts.getLanguages;
    return (langs as List).map((e) => e.toString()).toList()..sort();
  }

  void load(List<String> sentences, {int startAt = 0}) {
    stop();
    _sentences = sentences;
    currentIndex = startAt.clamp(0, sentences.isEmpty ? 0 : sentences.length - 1);
    notifyListeners();
  }

  bool get isPlaying => state == PlayerState.playing;

  Future<void> play({int? from}) async {
    if (_sentences.isEmpty) return;
    if (from != null) {
      await _tts.stop();
      currentIndex = from;
    }
    final session = ++_session;
    state = PlayerState.playing;
    notifyListeners();

    while (session == _session && currentIndex < _sentences.length) {
      wordStart = -1;
      wordEnd = -1;
      onSentenceChanged?.call(currentIndex);
      notifyListeners();
      final text = _sentences[currentIndex].trim();
      if (text.isNotEmpty) {
        await _tts.speak(text);
      }
      if (session != _session) return; // paused, stopped or jumped
      currentIndex++;
    }

    if (session == _session) {
      state = PlayerState.stopped;
      currentIndex = _sentences.length - 1;
      wordStart = wordEnd = -1;
      notifyListeners();
      onChapterFinished?.call();
    }
  }

  Future<void> pause() async {
    _session++;
    await _tts.stop();
    state = PlayerState.paused;
    wordStart = wordEnd = -1;
    notifyListeners();
  }

  Future<void> stop() async {
    _session++;
    await _tts.stop();
    state = PlayerState.stopped;
    wordStart = wordEnd = -1;
    notifyListeners();
  }

  Future<void> toggle() => isPlaying ? pause() : play();

  Future<void> skip(int delta) async {
    final next = (currentIndex + delta).clamp(0, _sentences.length - 1);
    if (isPlaying) {
      await play(from: next);
    } else {
      currentIndex = next;
      notifyListeners();
    }
  }

  Future<void> jumpTo(int index) async {
    if (isPlaying) {
      await play(from: index);
    } else {
      currentIndex = index;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _session++;
    _tts.stop();
    super.dispose();
  }
}
