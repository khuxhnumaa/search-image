import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'clip_assets.dart';

/// Minimal OpenAI CLIP BPE tokenizer implementation in Dart.
///
/// Expects assets:
/// - assets/tokenizer/vocab.json
/// - assets/tokenizer/merges.txt
///
/// If `assets/tokenizer/tokenizer.json` exists, it will be used instead
/// (HuggingFace tokenizers export containing `model.vocab` + `model.merges`).
class ClipTokenizer {
  ClipTokenizer._(
    this._encoder,
    this._bpeRanks,
    this._byteEncoder,
    this._startToken,
    this._endToken,
  );

  final Map<String, int> _encoder;
  final Map<String, int> _bpeRanks;
  final Map<int, String> _byteEncoder;
  final int _startToken;
  final int _endToken;

  static Future<ClipTokenizer> load() async {
    Map<String, int> encoder;
    List<String> merges;

    final tokenizerJson = await _tryLoadString(ClipAssets.tokenizerJson);
    if (tokenizerJson != null) {
      final obj = jsonDecode(tokenizerJson) as Map<String, dynamic>;
      final model = (obj['model'] as Map<String, dynamic>?) ?? const {};
      final vocab = (model['vocab'] as Map<String, dynamic>?) ?? const {};
      final mergesList = (model['merges'] as List?) ?? const [];

      encoder = vocab.map((k, v) => MapEntry(k, (v as num).toInt()));
      merges = mergesList.map((e) => e.toString()).toList();
    } else {
      final vocabRaw = await rootBundle.loadString(ClipAssets.vocabJson);
      final mergesRaw = await rootBundle.loadString(ClipAssets.mergesTxt);

      encoder = (jsonDecode(vocabRaw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt()));

      merges = mergesRaw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
    }

    // Each merge line is "a b".
    final bpeRanks = <String, int>{};
    for (var i = 0; i < merges.length; i++) {
      final parts = merges[i].split(RegExp(r'\s+'));
      if (parts.length != 2) continue;
      bpeRanks['${parts[0]} ${parts[1]}'] = i;
    }

    final byteEncoder = _bytesToUnicode();

    final startToken = encoder['<|startoftext|>'] ?? encoder['<start_of_text>'];
    final endToken = encoder['<|endoftext|>'] ?? encoder['<end_of_text>'];
    if (startToken == null || endToken == null) {
      throw StateError('Tokenizer is missing start/end tokens. Expected <|startoftext|>/<|endoftext|> or <start_of_text>/<end_of_text>.');
    }

    return ClipTokenizer._(encoder, bpeRanks, byteEncoder, startToken, endToken);
  }

  List<int> encodeToContextLength(String text, {int contextLength = ClipAssets.contextLength}) {
    final tokens = <int>[];
    tokens.add(_startToken);

    final bpeTokens = _tokenizeToBpeTokens(text);
    for (final t in bpeTokens) {
      final id = _encoder[t];
      if (id == null) continue;
      tokens.add(id);
      if (tokens.length >= contextLength - 1) break;
    }

    tokens.add(_endToken);

    // Pad with 0.
    if (tokens.length < contextLength) {
      tokens.addAll(List<int>.filled(contextLength - tokens.length, 0));
    } else if (tokens.length > contextLength) {
      tokens.removeRange(contextLength, tokens.length);
    }

    return tokens;
  }

  List<String> _tokenizeToBpeTokens(String text) {
    // CLIP-style pre-tokenization.
    // This is a simplified port of OpenAI CLIP's simple_tokenizer pattern.
    final cleaned = text.toLowerCase().replaceAll(RegExp(r"\s+"), ' ').trim();

    if (cleaned.isEmpty) return const [];

    final words = _clipTokenPattern.allMatches(cleaned).map((m) => m.group(0)!).toList();
    final out = <String>[];
    for (final w in words) {
      out.addAll(_bpe(w));
    }
    return out;
  }

  /// Byte-level BPE.
  List<String> _bpe(String token) {
    final bytes = utf8.encode(token);
    final chars = bytes.map((b) => _byteEncoder[b]!).join();

    // OpenAI CLIP appends </w> to the last character to mark end-of-word.
    var word = chars.split('').toList();
    if (word.isNotEmpty) {
      word[word.length - 1] = '${word.last}</w>';
    }
    var pairs = _getPairs(word);

    if (pairs.isEmpty) {
      return [chars];
    }

    while (true) {
      String? best;
      var bestRank = 1 << 30;

      for (final p in pairs) {
        final key = '${p.$1} ${p.$2}';
        final rank = _bpeRanks[key];
        if (rank != null && rank < bestRank) {
          bestRank = rank;
          best = key;
        }
      }

      if (best == null) {
        break;
      }

      final parts = best.split(' ');
      final first = parts[0];
      final second = parts[1];

      final newWord = <String>[];
      var i = 0;
      while (i < word.length) {
        final j = _indexOfPair(word, first, second, start: i);
        if (j == -1) {
          newWord.addAll(word.sublist(i));
          break;
        }
        newWord.addAll(word.sublist(i, j));
        newWord.add('$first$second');
        i = j + 2;
      }

      word = newWord;
      if (word.length == 1) {
        break;
      }
      pairs = _getPairs(word);
    }

    return word;
  }

  static Future<String?> _tryLoadString(String assetPath) async {
    try {
      return await rootBundle.loadString(assetPath);
    } catch (_) {
      return null;
    }
  }

  // Simplified CLIP tokenizer regex (ASCII-focused). This matches common English queries.
  static final RegExp _clipTokenPattern = RegExp(
    r"'s|'t|'re|'ve|'m|'ll|'d|[A-Za-z]+|[0-9]+|[^\sA-Za-z0-9]+",
  );

  static int _indexOfPair(List<String> word, String a, String b, {int start = 0}) {
    for (var i = start; i < word.length - 1; i++) {
      if (word[i] == a && word[i + 1] == b) return i;
    }
    return -1;
  }

  static Set<(String, String)> _getPairs(List<String> word) {
    final out = <(String, String)>{};
    for (var i = 0; i < word.length - 1; i++) {
      out.add((word[i], word[i + 1]));
    }
    return out;
  }

  static Map<int, String> _bytesToUnicode() {
    // Matches the byte->unicode mapping used by OpenAI CLIP.
    //
    // Source idea: map bytes to a set of unicode chars that are unlikely to occur in text.
    // Reference ranges:
    // 33..126, 161..172, 174..255
    final bs = <int>[];
    bs.addAll(List<int>.generate(94, (i) => i + 33));
    bs.addAll(List<int>.generate(12, (i) => i + 161));
    bs.addAll(List<int>.generate(82, (i) => i + 174));

    final cs = List<int>.from(bs);
    var n = 0;
    for (var b = 0; b < 256; b++) {
      if (!bs.contains(b)) {
        bs.add(b);
        cs.add(256 + n);
        n++;
      }
    }

    final map = <int, String>{};
    for (var i = 0; i < bs.length; i++) {
      map[bs[i]] = String.fromCharCode(cs[i]);
    }
    return map;
  }
}
