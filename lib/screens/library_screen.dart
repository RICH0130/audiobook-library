import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database.dart';
import '../services/epub_importer.dart';
import 'reader_screen.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _db = AppDatabase.instance;
  List<Book> _books = [];
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final books = await _db.books();
    if (!mounted) return;
    setState(() {
      _books = books;
      _loading = false;
    });
  }

  Future<void> _import() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );
    if (files.isEmpty) return;
    final file = files.first;
    if ((file.extension ?? '').toLowerCase() != '.epub' &&
        !file.name.toLowerCase().endsWith('.epub')) {
      _snack('請選擇 .epub 檔案');
      return;
    }
    setState(() => _importing = true);
    try {
      final bytes = await file.xFile.readAsBytes();
      final parsed = await EpubImporter.parse(bytes);
      await _db.insertBook(
        Book(
          title: parsed.title,
          author: parsed.author,
          chapterCount: parsed.chapters.length,
        ),
        (id) => [
          for (var i = 0; i < parsed.chapters.length; i++)
            Chapter(
              bookId: id,
              index: i,
              title: parsed.chapters[i].title,
              sentences: parsed.chapters[i].sentences,
            ),
        ],
      );
      _snack('已加入《${parsed.title}》');
      await _refresh();
    } on EpubImportException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('匯入失敗：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _delete(Book book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除書籍'),
        content: Text('要刪除《${book.title}》以及它的筆記和重點嗎？這個動作無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteBook(book.id!);
      await _refresh();
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的書架'),
        actions: [
          IconButton(
            tooltip: '設定',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _import,
        icon: _importing
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
        label: Text(_importing ? '匯入中…' : '匯入 EPUB'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.headphones_outlined, size: 72, color: scheme.primary),
                        const SizedBox(height: 16),
                        Text('書架還是空的', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text('點右下角「匯入 EPUB」加入第一本書，\n就能開始閱讀、朗讀和做筆記。',
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: _books.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final b = _books[i];
                    final progress =
                        b.chapterCount == 0 ? 0.0 : (b.lastChapter + 1) / b.chapterCount;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ReaderScreen(book: b)));
                          _refresh();
                        },
                        onLongPress: () => _delete(b),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  b.title.characters.first,
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: scheme.onPrimaryContainer),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 2),
                                    Text(b.author,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodySmall),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(value: progress),
                                    const SizedBox(height: 4),
                                    Text('第 ${b.lastChapter + 1} / ${b.chapterCount} 章',
                                        style: Theme.of(context).textTheme.labelSmall),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
