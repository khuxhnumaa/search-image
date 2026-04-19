import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class ClipStore {
  ClipStore._(this._db);

  final Database _db;

  static const _table = 'embeddings';

  static Future<String> _dbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'clip_index.db');
  }

  static Future<void> deleteDbFile() async {
    final dbPath = await _dbPath();
    await deleteDatabase(dbPath);
  }

  static Future<ClipStore> open() async {
    final dbPath = await _dbPath();

    final db = await openDatabase(
      dbPath,
      version: 1,
      onOpen: (db) async {
        // Improves write throughput during indexing.
        // Safe for our offline, single-writer use case.
        await db.rawQuery('PRAGMA journal_mode=WAL;');
        await db.rawQuery('PRAGMA synchronous=NORMAL;');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            asset_id TEXT PRIMARY KEY,
            embedding BLOB NOT NULL,
            dim INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');
        await db.execute('CREATE INDEX idx_dim ON $_table(dim);');
      },
    );

    return ClipStore._(db);
  }

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) as c FROM $_table');
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<bool> hasAsset(String assetId) async {
    final rows = await _db.query(
      _table,
      columns: const ['asset_id'],
      where: 'asset_id = ?',
      whereArgs: [assetId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> loadAllAssetIds() async {
    final rows = await _db.query(_table, columns: const ['asset_id']);
    return rows.map((r) => r['asset_id'] as String).toSet();
  }

  Future<void> putEmbedding({
    required String assetId,
    required int dim,
    required Uint8List embeddingBytes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert(
      _table,
      {
        'asset_id': assetId,
        'embedding': embeddingBytes,
        'dim': dim,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> putEmbeddingsBatch(
    List<({String assetId, int dim, Uint8List embeddingBytes})> rows, {
    bool ignoreIfExists = true,
  }) async {
    if (rows.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Fast insert many rows; return how many were attempted.
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final r in rows) {
        batch.insert(
          _table,
          {
            'asset_id': r.assetId,
            'embedding': r.embeddingBytes,
            'dim': r.dim,
            'updated_at': now,
          },
          conflictAlgorithm:
              ignoreIfExists ? ConflictAlgorithm.ignore : ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });

    return rows.length;
  }

  Future<List<({String assetId, Uint8List embedding, int dim})>> loadAllEmbeddings() async {
    final rows = await _db.query(_table, columns: const ['asset_id', 'embedding', 'dim']);
    return rows
        .map(
          (r) => (
            assetId: r['asset_id'] as String,
            embedding: r['embedding'] as Uint8List,
            dim: (r['dim'] as int),
          ),
        )
        .toList();
  }

  Future<void> close() async {
    await _db.close();
  }
}
