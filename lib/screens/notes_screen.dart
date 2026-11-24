import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database.dart';

/// All highlights and notes of a book, grouped by chapter.
/// Tapping a note pops it so the reader can jump to that sentence.
class NotesScreen extends StatefulWidget {
  final Book book;
  final List<Chapter> chapters;
  const NotesScreen({super.key, required this.book, required this.chapters});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await AppDatabase.instance.notes(widget.book.id!);
    if (mounted) {
      setState(() {
        _notes = notes;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<Note>>{};
    for (final n in _notes) {
      grouped.putIfAbsent(n.chapterIndex, () => []).add(n);
    }
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('筆記（${_notes.length}）')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('還沒有筆記。\n在閱讀頁長按任一句，就能畫重點或寫筆記。',
                        textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                        child: Text(
                          entry.key < widget.chapters.length
                              ? widget.chapters[entry.key].title
                              : '第 ${entry.key + 1} 章',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: scheme.primary),
                        ),
                      ),
                      for (final n in entry.value)
                        Dismissible(
                          key: ValueKey(n.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: scheme.errorContainer,
                            child: const Icon(Icons.delete_outline),
                          ),
                          onDismissed: (_) async {
                            await AppDatabase.instance.deleteNote(n.id!);
                            setState(() => _notes.remove(n));
                          },
                          child: Card(
                            child: InkWell(
                              onTap: () => Navigator.pop(context, n),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                      left: BorderSide(color: Color(n.color), width: 5)),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('「${n.quote}」',
                                        style: TextStyle(color: scheme.onSurfaceVariant)),
                                    if (n.text.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(n.text),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }
}
