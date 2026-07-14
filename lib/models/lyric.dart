/// 逐字时间标记
class WordTiming {
  final String word;
  final Duration start;
  final Duration end;
  const WordTiming({required this.word, required this.start, required this.end});
}

/// 歌词行
class LyricLine {
  final Duration time;
  final String text;
  final String? translation;
  final List<WordTiming>? wordTimings;

  const LyricLine({
    required this.time,
    required this.text,
    this.translation,
    this.wordTimings,
  });

  /// 根据播放位置计算该行中已播放的字符比例 [0.0, 1.0]
  double progressAt(Duration position) {
    if (wordTimings == null || wordTimings!.isEmpty) {
      // 无逐字时间时，用该行已过时间比例估算
      if (position < time) return 0.0;
      final elapsed = position - time;
      // 假设每行大约 3 秒
      return (elapsed.inMilliseconds / 3000.0).clamp(0.0, 1.0);
    }

    final totalDuration = wordTimings!.last.end - wordTimings!.first.start;
    if (totalDuration <= Duration.zero) return 0.0;
    final elapsed = position - wordTimings!.first.start;
    return (elapsed.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
  }
}

/// 歌词模型
class Lyric {
  final String songId;
  final List<LyricLine> lines;
  final bool hasTranslation;

  const Lyric({
    required this.songId,
    required this.lines,
    this.hasTranslation = false,
  });

  /// 解析 LRC 歌词（支持双语翻译行）
  /// 翻译行: 歌曲原行之后紧跟的同一时间戳行视为翻译
  factory Lyric.fromLrc(String lrc, {required String songId}) {
    final lines = <LyricLine>[];
    final regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    // 先解析所有行
    final rawLines = <_RawLrcLine>[];
    for (final rawLine in lrc.split('\n')) {
      final match = regExp.firstMatch(rawLine.trim());
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final msStr = match.group(3)!;
        final ms = msStr.length == 2 ? int.parse(msStr) * 10 : int.parse(msStr);
        final text = match.group(4)?.trim() ?? '';
        if (text.isNotEmpty) {
          rawLines.add(_RawLrcLine(
            time: Duration(minutes: min, seconds: sec, milliseconds: ms),
            text: text,
          ));
        }
      }
    }

    rawLines.sort((a, b) => a.time.compareTo(b.time));

    // 合并翻译行：同一时间戳的后续行作为前一行的翻译
    bool hasTranslation = false;
    for (int i = 0; i < rawLines.length; i++) {
      final current = rawLines[i];
      // 检查是否与上一行同一时间戳（翻译）
      if (i > 0 &&
          rawLines[i - 1].time == current.time &&
          lines.isNotEmpty) {
        // 将当前行作为翻译附加到上一行
        final prev = lines.removeLast();
        lines.add(LyricLine(
          time: prev.time,
          text: prev.text,
          translation: current.text,
          wordTimings: prev.wordTimings,
        ));
        hasTranslation = true;
      } else {
        lines.add(LyricLine(
          time: current.time,
          text: current.text,
        ));
      }
    }

    return Lyric(songId: songId, lines: lines, hasTranslation: hasTranslation);
  }

  /// 根据当前播放位置获取当前行索引
  int currentIndex(Duration position) {
    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].time) return i;
    }
    return 0;
  }
}

/// 内部原始解析行
class _RawLrcLine {
  final Duration time;
  final String text;
  const _RawLrcLine({required this.time, required this.text});
}
