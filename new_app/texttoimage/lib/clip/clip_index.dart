import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import 'clip_assets.dart';
import 'clip_math.dart';
import 'clip_preprocess.dart';
import 'clip_store.dart';
import 'clip_tflite.dart';
import 'clip_tokenizer.dart';

class ClipIndex {
  ClipIndex._(this._store, this._model, this._tokenizer);

  final ClipStore _store;
  final ClipTflite _model;
  final ClipTokenizer _tokenizer;

  final ValueNotifier<({int indexed, int total, bool running})> progress =
      ValueNotifier((indexed: 0, total: 0, running: false));

  static ClipIndex? _instance;

  static Future<ClipIndex> instance() async {
    final existing = _instance;
    if (existing != null) return existing;

    final store = await ClipStore.open();
    final model = await ClipTflite.load();
    final tokenizer = await ClipTokenizer.load();

    final created = ClipIndex._(store, model, tokenizer);
    _instance = created;
    return created;
  }

  Future<void> close() async {
    await _store.close();
    _model.close();
    progress.dispose();
    _instance = null;
  }

  Future<void> startIndexingAllImages({int pageSize = 100}) async {
    if (progress.value.running) return;

    progress.value = (indexed: 0, total: 0, running: true);

    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      progress.value = (indexed: 0, total: 0, running: false);
      return;
    }

    final paths = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (paths.isEmpty) {
      progress.value = (indexed: 0, total: 0, running: false);
      return;
    }

    // Prefer the "All"/"Recent" virtual album when available.
    final album = paths.firstWhere(
      (p) => p.isAll,
      orElse: () => paths.first,
    );
    final total = await album.assetCountAsync;

    // Progress should move even if items are skipped/already indexed.
    // We'll track both processed items and stored embeddings.
    var processed = 0;
    var stored = await _store.count();
    progress.value = (indexed: processed, total: total, running: true);

    // Avoid a per-asset "already indexed" DB query; load once.
    final existingIds = await _store.loadAllAssetIds();

    final pages = (total / pageSize).ceil();

    var logged = 0;

    // Batch DB writes for speed.
    final pending = <({String assetId, int dim, Uint8List embeddingBytes})>[];
    const batchSize = 25;
    const progressEvery = 5;

    Future<void> flushPending() async {
      if (pending.isEmpty) return;
      final wrote = await _store.putEmbeddingsBatch(pending, ignoreIfExists: true);
      stored += wrote;
      if (stored == wrote || stored % 100 == 0) {
        debugPrint('Indexing progress: stored=$stored processed=$processed/$total');
      }
      pending.clear();
    }

    for (var page = 0; page < pages; page++) {
      final items = await album.getAssetListPaged(page: page, size: pageSize);
      for (final asset in items) {
        try {
          final r = await _encodeOne(asset, existingIds).timeout(const Duration(seconds: 15));
          if (r != null) {
            pending.add(r);
            existingIds.add(r.assetId);
            if (pending.length >= batchSize) {
              await flushPending();
            }
          }
        } catch (e, st) {
          // Log a few failures so we can diagnose device-specific issues.
          if (logged < 5) {
            logged++;
            debugPrint('Indexing error for asset ${asset.id}: $e');
            debugPrint('$st');
          }
        }

        processed++;
        if (processed % progressEvery == 0 || processed == total) {
          progress.value = (indexed: processed, total: total, running: true);
        }
      }
    }

    await flushPending();

    debugPrint('Indexing finished. processed=$processed stored=$stored total=$total');
    progress.value = (indexed: processed, total: total, running: false);
  }

  Future<({String assetId, int dim, Uint8List embeddingBytes})?> _encodeOne(
    AssetEntity asset,
    Set<String> existingIds,
  ) async {
    final assetId = asset.id;
    if (existingIds.contains(assetId)) return null;

    // Ensure we get a JPEG/PNG-like encoded thumbnail bytes that Dart can decode.
    // Some devices store originals as HEIC; forcing JPEG thumbnails avoids decode failures.
    final inputShape = _model.imageInputShape;
    if (inputShape.length != 4) {
      throw StateError('Unexpected image input shape: $inputShape');
    }
    final isNhwc = inputShape[3] == 3;
    final h = isNhwc ? inputShape[1] : inputShape[2];
    final w = isNhwc ? inputShape[2] : inputShape[3];

    Uint8List? encoded;
    try {
      encoded = await asset.thumbnailDataWithOption(
        ThumbnailOption(
          size: ThumbnailSize(w, h),
          format: ThumbnailFormat.jpeg,
          quality: 90,
        ),
      );
    } catch (_) {
      // Fall back below.
    }

    encoded ??= await asset.thumbnailDataWithSize(
      ThumbnailSize(w, h),
      quality: 95,
    );

    // Last resort: try original bytes (may still be unsupported formats).
    encoded ??= await asset.originBytes;

    if (encoded == null) return null;

    final input = preprocessImageToFloat32(encoded, inputShape: inputShape);
    final emb = l2NormalizeOrNull(_model.runImage(input));
    if (emb == null) return null;

    return (
      assetId: assetId,
      dim: emb.length,
      embeddingBytes: emb.buffer.asUint8List(emb.offsetInBytes, emb.lengthInBytes),
    );
  }

  Float32List _encodeTextQuery(String query) {
    final q = query.trim();
    if (q.isEmpty) {
      throw StateError('Query is empty');
    }

    // CLIP typically performs better with simple prompt templates for single-word queries.
    final isSingleWord = !q.contains(RegExp(r'\s'));
    final prompts = <String>[q];
    if (isSingleWord) {
      prompts.addAll([
        'a photo of $q',
        'a photo of a $q',
        'a picture of $q',
        'an image of $q',
      ]);
    }

    final acc = Float32List(_model.textEmbeddingDim);
    var used = 0;
    for (final p in prompts) {
      final tokens = _tokenizer.encodeToContextLength(p, contextLength: ClipAssets.contextLength);
      final e = l2NormalizeOrNull(_model.runText(tokens));
      if (e == null) continue;
      // Accumulate.
      final n = math.min(acc.length, e.length);
      for (var i = 0; i < n; i++) {
        acc[i] += e[i];
      }
      used++;
    }

    if (used == 0) {
      throw StateError('Text encoder produced an invalid embedding (all zeros/NaN). Check tokenizer/model pairing.');
    }

    final out = l2NormalizeOrNull(acc);
    if (out == null) {
      throw StateError('Failed to normalize text embedding (unexpected).');
    }
    return out;
  }

  Future<List<({String assetId, double score})>> search(String query, {int k = 30}) async {
    final textEmb = _encodeTextQuery(query);

    final rows = await _store.loadAllEmbeddings();
    if (rows.isEmpty) return const [];

    final scored = <({String assetId, double score})>[];

    for (final r in rows) {
      if (r.dim != textEmb.length) {
        // Skip embeddings created by a different model/config.
        continue;
      }

      var bytes = r.embedding;
      // Some platform implementations return a Uint8List view into a larger
      // buffer with a non-4-byte-aligned offset, which breaks Float32List.view.
      if (bytes.offsetInBytes % Float32List.bytesPerElement != 0) {
        bytes = Uint8List.fromList(bytes);
      }
      if (bytes.lengthInBytes % Float32List.bytesPerElement != 0) {
        // Corrupt/partial row; skip it rather than crashing search.
        continue;
      }

      final emb = bytes.buffer.asFloat32List(
        bytes.offsetInBytes,
        bytes.lengthInBytes ~/ Float32List.bytesPerElement,
      );
      // Guard against legacy/non-normalized vectors; normalize on the fly when needed.
      Float32List? embNorm;
      final n = l2Norm(emb);
      if (n.isFinite && (n - 1.0).abs() < 0.05) {
        embNorm = emb;
      } else {
        embNorm = l2NormalizeOrNull(emb);
      }
      if (embNorm == null) continue;

      final s = dot(textEmb, embNorm);
      if (!s.isFinite) continue;
      scored.add((assetId: r.assetId, score: s));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    if (scored.length > k) {
      return scored.sublist(0, k);
    }
    return scored;
  }
}
