import 'dart:convert';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Book {
  final int? id;
  /// Stable id for future cloud sync / sharing (phase 2).
  final String uid;
  final String title;
  final String author;
  final int chapterCount;
  final int lastChapter;
  final int lastSentence;
  final DateTime addedAt;

  Book({
    this.id,
    String? uid,
    required this.title,
    required this.author,
    required this.chapterCount,
    this.lastChapter = 0,
    this.lastSentence = 0,
    DateTime? addedAt,
  })  : uid = uid ?? _uuid.v4(),
        addedAt = addedAt ?? DateTime.now();

  Map<String, Object?> toMap() => {
        'id': id,
        'uid': uid,
        'title': title,
        'author': author,
        'chapter_count': chapterCount,
        'last_chapter': lastChapter,
        'last_sentence': lastSentence,
        'added_at': addedAt.millisecondsSinceEpoch,
      };

  factory Book.fromMap(Map<String, Object?> m) => Book(
        id: m['id'] as int?,
        uid: m['uid'] as String?,
        title: m['title'] as String,
        author: m['author'] as String,
        chapterCount: m['chapter_count'] as int,
        lastChapter: m['last_chapter'] as int? ?? 0,
        lastSentence: m['last_sentence'] as int? ?? 0,
        addedAt: DateTime.fromMillisecondsSinceEpoch(m['added_at'] as int),
      );
}

class Chapter {
  final int bookId;
  final int index;
  final String title;
  final List<String> sentences;

  Chapter({
    required this.bookId,
    required this.index,
    required this.title,
    required this.sentences,
  });

  String get fullText => sentences.join();

  Map<String, Object?> toMap() => {
        'book_id': bookId,
        'idx': index,
        'title': title,
        'sentences': jsonEncode(sentences),
      };

  factory Chapter.fromMap(Map<String, Object?> m) => Chapter(
        bookId: m['book_id'] as int,
        index: m['idx'] as int,
        title: m['title'] as String,
        sentences:
            (jsonDecode(m['sentences'] as String) as List).cast<String>(),
      );
}

/// A highlight, optionally with a note, attached to one sentence.
class Note {
  final int? id;
  /// Stable id for future cloud sync / sharing (phase 2).
  final String uid;
  final int bookId;
  final int chapterIndex;
  final int sentenceIndex;
  final String quote;
  final String text;
  final int color;
  final DateTime createdAt;

  Note({
    this.id,
    String? uid,
    required this.bookId,
    required this.chapterIndex,
    required this.sentenceIndex,
    required this.quote,
    this.text = '',
    this.color = 0xFFFFE082,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : uid = uid ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final DateTime updatedAt;

  Note copyWith({String? text, int? color}) => Note(
        id: id,
        uid: uid,
        bookId: bookId,
        chapterIndex: chapterIndex,
        sentenceIndex: sentenceIndex,
        quote: quote,
        text: text ?? this.text,
        color: color ?? this.color,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'uid': uid,
        'book_id': bookId,
        'chapter_idx': chapterIndex,
        'sentence_idx': sentenceIndex,
        'quote': quote,
        'text': text,
        'color': color,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: m['id'] as int?,
        uid: m['uid'] as String?,
        bookId: m['book_id'] as int,
        chapterIndex: m['chapter_idx'] as int,
        sentenceIndex: m['sentence_idx'] as int,
        quote: m['quote'] as String,
        text: m['text'] as String? ?? '',
        color: m['color'] as int? ?? 0xFFFFE082,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt: m['updated_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
      );
}

/// AI-generated keywords and key points for one chapter.
class ChapterInsight {
  final int bookId;
  final int chapterIndex;
  final List<String> keywords;
  final List<String> keyPoints;
  final String oneLine;

  ChapterInsight({
    required this.bookId,
    required this.chapterIndex,
    required this.keywords,
    required this.keyPoints,
    required this.oneLine,
  });

  Map<String, Object?> toMap() => {
        'book_id': bookId,
        'chapter_idx': chapterIndex,
        'keywords': jsonEncode(keywords),
        'key_points': jsonEncode(keyPoints),
        'one_line': oneLine,
      };

  factory ChapterInsight.fromMap(Map<String, Object?> m) => ChapterInsight(
        bookId: m['book_id'] as int,
        chapterIndex: m['chapter_idx'] as int,
        keywords: (jsonDecode(m['keywords'] as String) as List).cast<String>(),
        keyPoints:
            (jsonDecode(m['key_points'] as String) as List).cast<String>(),
        oneLine: m['one_line'] as String? ?? '',
      );
}
