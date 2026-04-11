// lib/data/repositories/lyrics_repo.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import '../models/lyrics_line.dart';

class LyricsRepository {
  static const _lrclibBase = 'https://lrclib.net/api';
  String? geniusApiKey;
  String? anthropicApiKey;

  Future<Lyrics> fetchLyrics(Track track) async {
    final title  = _cleanTitle(track.title);
    final artist = _cleanArtist(track.artist);
    debugPrint('[Lyrics] "$title" — "$artist"');

    final exact = await _lrclibGet(title, artist, track.album);
    if (exact != null && !exact.isEmpty) { debugPrint('[Lyrics] LRCLIB exact ✓'); return exact; }

    final search = await _lrclibSearch(title, artist);
    if (search != null && !search.isEmpty) { debugPrint('[Lyrics] LRCLIB search ✓'); return search; }

    if (geniusApiKey != null && geniusApiKey!.isNotEmpty) {
      final g = await _fetchGenius(title, artist);
      if (g != null && !g.isEmpty) { debugPrint('[Lyrics] Genius ✓'); return g; }
    }

    if (anthropicApiKey != null && anthropicApiKey!.isNotEmpty) {
      final ai = await _generateWithAI(title, artist);
      if (ai != null && !ai.isEmpty) { debugPrint('[Lyrics] AI ✓'); return ai; }
    }

    return Lyrics.empty();
  }

  String _cleanTitle(String raw) => raw
      .replaceAll(RegExp(r'\(Official\s*(Music|Lyric)?\s*Video\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\[Official\s*(Music|Lyric)?\s*Video\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\(Official Audio\)',  caseSensitive: false), '')
      .replaceAll(RegExp(r'\[Official Audio\]',  caseSensitive: false), '')
      .replaceAll(RegExp(r'\(Lyric Video\)',      caseSensitive: false), '')
      .replaceAll(RegExp(r'\((Audio|HD|HQ|4K|Official)\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\(feat\.[^)]*\)',      caseSensitive: false), '')
      .replaceAll(RegExp(r'\[feat\.[^\]]*\]',    caseSensitive: false), '')
      .replaceAll(RegExp(r'ft\.\s*[^()[\]]+',    caseSensitive: false), '')
      .replaceAll(RegExp(r'\(\s*\)'), '').replaceAll(RegExp(r'\[\s*\]'), '')
      .trim();

  String _cleanArtist(String raw) => raw
      .replaceAll(RegExp(r'VEVO$',              caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*-\s*Topic$',      caseSensitive: false), '')
      .trim();

  Future<Lyrics?> _lrclibGet(String title, String artist, String album) async {
    try {
      final params = {'artist_name': artist, 'track_name': title};
      if (album.isNotEmpty) params['album_name'] = album;
      final res = await http.get(
        Uri.parse('$_lrclibBase/get').replace(queryParameters: params),
      ).timeout(const Duration(seconds: 15)); // Changed from 8 to 15
      if (res.statusCode != 200) return null;
      return _parseLrclibBody(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) { debugPrint('[LRCLIB GET] $e'); return null; }
  }

  Future<Lyrics?> _lrclibSearch(String title, String artist) async {
    try {
      final res = await http.get(
        Uri.parse('$_lrclibBase/search')
            .replace(queryParameters: {'track_name': title, 'artist_name': artist}),
      ).timeout(const Duration(seconds: 15)); // Changed from 8 to 15
      if (res.statusCode != 200) return null;
      final results = jsonDecode(res.body) as List;
      if (results.isEmpty) return null;
      Map<String, dynamic>? best;
      for (final r in results.cast<Map<String, dynamic>>()) {
        if (r['syncedLyrics'] != null && (r['syncedLyrics'] as String).isNotEmpty) {
          best = r; break;
        }
        best ??= r;
      }
      return best == null ? null : _parseLrclibBody(best);
    } catch (e) { debugPrint('[LRCLIB SEARCH] $e'); return null; }
  }

  Lyrics? _parseLrclibBody(Map<String, dynamic> d) {
    if (d['syncedLyrics'] != null && (d['syncedLyrics'] as String).isNotEmpty) {
      final p = LrcParser.parse(d['syncedLyrics'] as String);
      return Lyrics(lines: p.lines, source: LyricsSource.lrclib, isSynced: true);
    }
    if (d['plainLyrics'] != null && (d['plainLyrics'] as String).isNotEmpty) {
      final lines = (d['plainLyrics'] as String)
          .split('\n').map((l) => LyricsLine(text: l.trim())).toList();
      return Lyrics(lines: lines, source: LyricsSource.lrclib, isSynced: false);
    }
    return null;
  }

  // Genius — plain HTTP scrape approach (no package dependency)
  Future<Lyrics?> _fetchGenius(String title, String artist) async {
    try {
      final searchRes = await http.get(
        Uri.parse('https://api.genius.com/search?q=${Uri.encodeComponent('$title $artist')}'),
        headers: {'Authorization': 'Bearer $geniusApiKey'},
      ).timeout(const Duration(seconds: 10));
      if (searchRes.statusCode != 200) return null;
      final hits = (jsonDecode(searchRes.body)['response']?['hits'] as List?) ?? [];
      if (hits.isEmpty) return null;
      // Return placeholder — full scraping would need html package
      // For now, indicate that Genius found the song
      debugPrint('[Genius] Found match, full scrape pending html package');
      return null;
    } catch (e) { debugPrint('[Genius] $e'); return null; }
  }

  Future<Lyrics?> _generateWithAI(String title, String artist) async {
    try {
      final res = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type':     'application/json',
          'x-api-key':         anthropicApiKey!,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model':      'claude-haiku-4-5-20251001',
          'max_tokens': 1024,
          'messages':   [{'role': 'user', 'content':
            'Generate lyrics for "$title" by $artist. '
            'Return ONLY the lyrics. No headers, markdown, or explanations. '
            'Separate verses with a blank line.'}],
        }),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final content = (jsonDecode(res.body)['content'] as List?)?.first?['text'] as String?;
      if (content == null || content.isEmpty) return null;
      return Lyrics(
        lines: content.split('\n').map((l) => LyricsLine(text: l)).toList(),
        source: LyricsSource.aiGenerated,
        isSynced: false,
        isAiGenerated: true,
      );
    } catch (e) { debugPrint('[AI] $e'); return null; }
  }
}
