// lib/data/models/lyrics_line.dart

enum LyricsSource { localLrc, localTxt, embedded, lrclib, genius, musixmatch, aiGenerated }

class LyricsLine {
  final Duration? timestamp;  // null = unsynced
  final String text;
  final List<WordTiming>? words; // word-level for karaoke

  const LyricsLine({
    this.timestamp,
    required this.text,
    this.words,
  });

  bool get isSynced => timestamp != null;
  bool get hasWordTiming => words != null && words!.isNotEmpty;
}

class WordTiming {
  final String word;
  final Duration start;
  final Duration end;

  const WordTiming({
    required this.word,
    required this.start,
    required this.end,
  });
}

class Lyrics {
  final List<LyricsLine> lines;
  final LyricsSource source;
  final bool isSynced;
  final bool isAiGenerated;

  const Lyrics({
    required this.lines,
    required this.source,
    this.isSynced = false,
    this.isAiGenerated = false,
  });

  static Lyrics empty() => const Lyrics(
        lines: [],
        source: LyricsSource.lrclib,
        isSynced: false,
      );

  bool get isEmpty => lines.isEmpty;
}

/// LRC file parser — handles standard [mm:ss.xx] timestamps
class LrcParser {
  static Lyrics parse(String lrcContent) {
    final lines = <LyricsLine>[];
    final rawLines = lrcContent.split('\n');

    // Regex: [mm:ss.xx] or [mm:ss.xxx]
    final timeRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');

    for (final raw in rawLines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      // Skip metadata tags like [ti:], [ar:], [al:], [by:]
      if (RegExp(r'^\[(ti|ar|al|by|la|length):').hasMatch(trimmed)) continue;

      final match = timeRegex.firstMatch(trimmed);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centisStr = match.group(3)!;
        final millis = centisStr.length == 2
            ? int.parse(centisStr) * 10
            : int.parse(centisStr);

        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );
        final text = trimmed.substring(match.end).trim();
        if (text.isNotEmpty) {
          lines.add(LyricsLine(timestamp: timestamp, text: text));
        }
      } else if (!trimmed.startsWith('[')) {
        // Plain unsynced line
        lines.add(LyricsLine(text: trimmed));
      }
    }

    // Sort by timestamp
    lines.sort((a, b) {
      if (a.timestamp == null && b.timestamp == null) return 0;
      if (a.timestamp == null) return 1;
      if (b.timestamp == null) return -1;
      return a.timestamp!.compareTo(b.timestamp!);
    });

    final hasSynced = lines.any((l) => l.isSynced);

    return Lyrics(
      lines: lines,
      source: LyricsSource.localLrc,
      isSynced: hasSynced,
    );
  }
}
