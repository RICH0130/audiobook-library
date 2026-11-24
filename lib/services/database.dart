import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'audiobook_library.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE books(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uid TEXT NOT NULL UNIQUE,
            title TEXT NOT NULL,
            author TEXT NOT NULL,
            chapter_count INTEGER NOT NULL,
            last_chapter INTEGER NOT NULL DEFAULT 0,
            last_sentence INTEGER NOT NULL DEFAULT 0,
            added_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE chapters(
            book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
            idx INTEGER NOT NULL,
            title TEXT NOT NULL,
            sentences TEXT NOT NULL,
            PRIMARY KEY(book_id, idx)
          )''');
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uid TEXT NOT NULL UNIQUE,
            book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
            chapter_idx INTEGER NOT NULL,
            sentence_idx INTEGER NOT NULL,
            quote TEXT NOT NULL,
            text TEXT NOT NULL DEFAULT '',
            color INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE insights(
            book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
            chapter_idx INTEGER NOT NULL,
            keywords TEXT NOT NULL,
            key_points TEXT NOT NULL,
            one_line TEXT NOT NULL DEFAULT '',
            PRIMARY KEY(book_id, chapter_idx)
          )''');
      },
    );
  }

  // Books
  Future<int> insertBook(Book book, List<Chapter> Function(int id) chapters) async {
    final d = await db;
    return d.transaction((txn) async {
      final map = book.toMap()..remove('id');
      final id = await txn.insert('books', map);
      final batch = txn.batch();
      for (final c in chapters(id)) {
        batch.insert('chapters', c.toMap());
      }
      await batch.commit(noResult: true);
      return id;
    });
  }

  Future<List<Book>> books() async {
    final d = await db;
    final rows = await d.query('books', orderBy: 'added_at DESC');
    return rows.map(Book.fromMap).toList();
  }

  Future<void> deleteBook(int id) async {
    final d = await db;
    await d.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveProgress(int bookId, int chapter, int sentence) async {
    final d = await db;
    await d.update(
      'books',
      {'last_chapter': chapter, 'last_sentence': sentence},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  // Chapters
  Future<List<Chapter>> chapters(int bookId) async {
    final d = await db;
    final rows = await d.query('chapters',
        where: 'book_id = ?', whereArgs: [bookId], orderBy: 'idx');
    return rows.map(Chapter.fromMap).toList();
  }

  // Notes
  Future<List<Note>> notes(int bookId) async {
    final d = await db;
    final rows = await d.query('notes',
        where: 'book_id = ?',
        whereArgs: [bookId],
        orderBy: 'chapter_idx, sentence_idx');
    return rows.map(Note.fromMap).toList();
  }

  Future<Note> upsertNote(Note note) async {
    final d = await db;
    if (note.id == null) {
      final map = note.toMap()..remove('id');
      final id = await d.insert('notes', map);
      return Note.fromMap({...map, 'id': id});
    }
    await d.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
    return note;
  }

  Future<void> deleteNote(int id) async {
    final d = await db;
    await d.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // Insights
  Future<Map<int, ChapterInsight>> insights(int bookId) async {
    final d = await db;
    final rows =
        await d.query('insights', where: 'book_id = ?', whereArgs: [bookId]);
    return {
      for (final r in rows.map(ChapterInsight.fromMap)) r.chapterIndex: r,
    };
  }

  Future<void> saveInsight(ChapterInsight insight) async {
    final d = await db;
    await d.insert('insights', insight.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
