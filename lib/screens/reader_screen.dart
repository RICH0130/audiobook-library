import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../models/models.dart';
import '../services/database.dart';
import '../services/settings.dart';
import '../services/tts_player.dart';
import '../widgets/sentence_text.dart';
import 'adhd_screen.dart';
import 'notes_screen.dart';

const noteColors = [0xFFFFE082, 0xFFA5D6A7, 0xFF90CAF9, 0xFFF48FB1];

class ReaderScreen extends StatefulWidget {
  final Book book;
  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _db = AppDatabase.instance;
  final _player = TtsPlayer();
  final _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();

  List<Chapter> _chapters = [];
  Map<int, ChapterInsight> _insights = {};
  List<Note> _notes = [];
  int _chapterIndex = 0;
  bool _loading = true;
  bool _focusMode = false; // ADHD quick read: only key sentences
  bool _autoFollow = true;
  int _lastFollowed = -1;

  Chapter get _chapter => _chapters[_chapterIndex];

  @override
  void initState() {
    super.initState();
    _player.addListener(_onPlayer);
    _player.onSentenceChanged = (i) => _db.saveProgress(widget.book.id!, _chapterIndex, i);
    _player.onChapterFinished = () {
      if (_chapterIndex < _chapters.length - 1) {
        _openChapter(_chapterIndex + 1, autoplay: true);
      }
    };
    _load();
  }

  Future<void> _load() async {
    final settings = context.read<AppSettings>();
    final chapters = await _db.chapters(widget.book.id!);
    final insights = await _db.insights(widget.book.id!);
    final notes = await _db.notes(widget.book.id!);
    await _player.configure(
        language: settings.language, rate: settings.speechRate, pitch: settings.pitch);
    if (!mounted) return;
    setState(() {
      _chapters = chapters;
      _insights = insights;
      _notes = notes;
      _loading = false;
    });
    final start = widget.book.lastChapter.clamp(0, chapters.length - 1);
    _openChapter(start, sentence: widget.book.lastSentence);
  }

  void _openChapter(int index, {int sentence = 0, bool autoplay = false}) {
    setState(() {
      _chapterIndex = index;
      _lastFollowed = -1;
    });
    _player.load(_chapter.sentences, startAt: sentence);
    _db.saveProgress(widget.book.id!, index, sentence);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.isAttached) {
        _scroll.jumpTo(index: _visibleIndexOf(sentence).clamp(0, 1 << 30));
      }
    });
    if (autoplay) _player.play(from: sentence);
  }

  void _onPlayer() {
    if (!mounted) return;
    setState(() {});
    final i = _player.currentIndex;
    if (_autoFollow && _player.isPlaying && i != _lastFollowed && _scroll.isAttached) {
      _lastFollowed = i;
      final vi = _visibleIndexOf(i);
      if (vi < 0) return;
      final visible = _positions.itemPositions.value
          .any((p) => p.index == vi && p.itemLeadingEdge > 0.05 && p.itemTrailingEdge < 0.75);
      if (!visible) {
        _scroll.scrollTo(
            index: vi, alignment: 0.25, duration: const Duration(milliseconds: 350));
      }
    }
  }

  // ---- Focus mode helpers ----
  List<String> get _keywords => _insights[_chapterIndex]?.keywords ?? const [];

  Map<int, Note> get _noteBySentence => {
        for (final n in _notes.where((n) => n.chapterIndex == _chapterIndex))
          n.sentenceIndex: n,
      };

  /// Indexes of sentences shown in the list.
  List<int> get _visibleSentences {
    final all = List<int>.generate(_chapter.sentences.length, (i) => i);
    if (!_focusMode) return all;
    final kws = _keywords;
    final noted = _noteBySentence.keys.toSet();
    return all
        .where((i) =>
            noted.contains(i) || kws.any((k) => _chapter.sentences[i].contains(k)))
        .toList();
  }

  int _visibleIndexOf(int sentence) {
    if (!_focusMode) return sentence;
    final v = _visibleSentences;
    final i = v.indexWhere((s) => s >= sentence);
    return i < 0 ? v.length - 1 : i;
  }

  // ---- Notes ----
  Future<void> _sentenceActions(int sentenceIndex) async {
    final existing = _noteBySentence[sentenceIndex];
    final text = _chapter.sentences[sentenceIndex].trim();
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              const Text('畫重點'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final c in noteColors)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _saveNote(sentenceIndex, color: c, existing: existing);
                        },
                        child: CircleAvatar(
                          backgroundColor: Color(c),
                          radius: 18,
                          child: existing?.color == c
                              ? const Icon(Icons.check, color: Colors.black54)
                              : null,
                        ),
                      ),
                    ),
                  if (existing != null)
                    IconButton(
                      tooltip: '移除重點',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _db.deleteNote(existing.id!);
                        _reloadNotes();
                      },
                    ),
                ],
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_note),
                title: Text(existing?.text.isNotEmpty == true ? '編輯筆記' : '寫筆記'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _editNote(sentenceIndex, existing);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_arrow),
                title: const Text('從這句開始朗讀'),
                onTap: () {
                  Navigator.pop(ctx);
                  _player.play(from: sentenceIndex);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.copy),
                title: const Text('複製'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveNote(int sentenceIndex,
      {int? color, String? text, Note? existing}) async {
    final note = existing?.copyWith(color: color, text: text) ??
        Note(
          bookId: widget.book.id!,
          chapterIndex: _chapterIndex,
          sentenceIndex: sentenceIndex,
          quote: _chapter.sentences[sentenceIndex].trim(),
          color: color ?? noteColors.first,
          text: text ?? '',
        );
    await _db.upsertNote(note);
    await _reloadNotes();
  }

  Future<void> _editNote(int sentenceIndex, Note? existing) async {
    final ctrl = TextEditingController(text: existing?.text ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('筆記'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 6,
          minLines: 3,
          decoration: const InputDecoration(
              hintText: '寫下你的想法…', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('儲存')),
        ],
      ),
    );
    if (result != null) {
      await _saveNote(sentenceIndex, text: result, existing: existing);
    }
  }

  Future<void> _reloadNotes() async {
    final notes = await _db.notes(widget.book.id!);
    if (mounted) setState(() => _notes = notes);
  }

  Future<void> _reloadInsights() async {
    final insights = await _db.insights(widget.book.id!);
    if (mounted) setState(() => _insights = insights);
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayer);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final settings = context.watch<AppSettings>();
    final visible = _visibleSentences;
    final notes = _noteBySentence;
    final keywords = settings.showKeywords ? _keywords : const <String>[];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.book.title,
                style: Theme.of(context).textTheme.labelMedium,
                overflow: TextOverflow.ellipsis),
            Text(_chapter.title, overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _focusMode ? '顯示全文' : 'ADHD 快讀：只看重點句',
            isSelected: _focusMode,
            icon: const Icon(Icons.bolt_outlined),
            selectedIcon: const Icon(Icons.bolt),
            onPressed: () {
              if (!_focusMode && _keywords.isEmpty && notes.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('這一章還沒有關鍵字或重點，先到「重點」頁產生 AI 重點')));
                return;
              }
              setState(() => _focusMode = !_focusMode);
            },
          ),
          IconButton(
            tooltip: '筆記',
            icon: const Icon(Icons.sticky_note_2_outlined),
            onPressed: () async {
              final target = await Navigator.push<Note>(
                context,
                MaterialPageRoute(
                    builder: (_) => NotesScreen(book: widget.book, chapters: _chapters)),
              );
              await _reloadNotes();
              if (target != null) {
                _openChapter(target.chapterIndex, sentence: target.sentenceIndex);
              }
            },
          ),
          IconButton(
            tooltip: '重點與 PDF',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () async {
              await _player.pause();
              if (!context.mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AdhdScreen(book: widget.book, chapters: _chapters)),
              );
              await _reloadInsights();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView.builder(
            itemCount: _chapters.length,
            itemBuilder: (ctx, i) => ListTile(
              selected: i == _chapterIndex,
              title: Text(_chapters[i].title),
              trailing: _insights.containsKey(i)
                  ? Icon(Icons.auto_awesome, size: 16, color: scheme.primary)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _openChapter(i);
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_focusMode)
            Container(
              width: double.infinity,
              color: scheme.tertiaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text('ADHD 快讀中：顯示 ${visible.length} / ${_chapter.sentences.length} 句重點句',
                  style: TextStyle(color: scheme.onTertiaryContainer)),
            ),
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (n) {
                // Pause auto-follow briefly when the reader scrolls by hand.
                if (_player.isPlaying && n.metrics.axis == Axis.vertical) {
                  _autoFollow = false;
                  Future.delayed(const Duration(seconds: 6), () => _autoFollow = true);
                }
                return false;
              },
              child: ScrollablePositionedList.builder(
                itemScrollController: _scroll,
                itemPositionsListener: _positions,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: visible.length,
                itemBuilder: (ctx, vi) {
                  final si = visible[vi];
                  final s = _chapter.sentences[si];
                  final note = notes[si];
                  return Padding(
                    padding: EdgeInsets.only(bottom: s.endsWith('\n') ? 14 : 2),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _player.jumpTo(si),
                      onDoubleTap: () => _player.play(from: si),
                      onLongPress: () => _sentenceActions(si),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SentenceText(
                            text: s,
                            keywords: keywords,
                            isCurrent: si == _player.currentIndex,
                            spokenStart: _player.wordStart,
                            spokenEnd: _player.wordEnd,
                            highlight: note == null ? null : Color(note.color),
                            fontSize: settings.fontSize,
                          ),
                          if (note != null && note.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 2, 8, 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.edit_note, size: 18, color: scheme.outline),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(note.text,
                                        style: TextStyle(
                                            fontSize: settings.fontSize * 0.8,
                                            color: scheme.onSurfaceVariant)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _PlayerBar(
            player: _player,
            settings: settings,
            hasPrev: _chapterIndex > 0,
            hasNext: _chapterIndex < _chapters.length - 1,
            onPrevChapter: () => _openChapter(_chapterIndex - 1),
            onNextChapter: () => _openChapter(_chapterIndex + 1),
            onRateChanged: (r) async {
              await settings.setSpeechRate(r);
              await _player.configure(
                  language: settings.language, rate: r, pitch: settings.pitch);
              if (_player.isPlaying) _player.play(from: _player.currentIndex);
            },
          ),
        ],
      ),
    );
  }
}

class _PlayerBar extends StatelessWidget {
  final TtsPlayer player;
  final AppSettings settings;
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;
  final ValueChanged<double> onRateChanged;

  const _PlayerBar({
    required this.player,
    required this.settings,
    required this.hasPrev,
    required this.hasNext,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.onRateChanged,
  });

  static const _rates = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: '上一章',
                onPressed: hasPrev ? onPrevChapter : null,
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton(
                tooltip: '上一句',
                onPressed: () => player.skip(-1),
                icon: const Icon(Icons.replay),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    shape: const CircleBorder(), padding: const EdgeInsets.all(14)),
                onPressed: player.toggle,
                child: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow, size: 30),
              ),
              IconButton(
                tooltip: '下一句',
                onPressed: () => player.skip(1),
                icon: const Icon(Icons.forward),
              ),
              IconButton(
                tooltip: '下一章',
                onPressed: hasNext ? onNextChapter : null,
                icon: const Icon(Icons.skip_next),
              ),
              PopupMenuButton<double>(
                tooltip: '語速',
                initialValue: settings.speechRate,
                onSelected: onRateChanged,
                itemBuilder: (_) => [
                  for (final r in _rates)
                    PopupMenuItem(value: r, child: Text('${(r * 2).toStringAsFixed(1)}x')),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${(settings.speechRate * 2).toStringAsFixed(1)}x',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
