import 'package:flutter/foundation.dart';

/// 심플 모드 게임에서 효과음 재생을 추적하기 위한 버퍼 (UI 복사·스크롤용).
class SfxPlayLog {
  SfxPlayLog._();

  static bool enabled = false;

  static final ValueNotifier<List<String>> lines = ValueNotifier<List<String>>([]);

  static const int maxLines = 500;

  static void append(String message) {
    if (!enabled) return;
    final ts = DateTime.now().toIso8601String();
    final next = List<String>.from(lines.value)..add('[$ts] $message');
    if (next.length > maxLines) {
      next.removeRange(0, next.length - maxLines);
    }
    lines.value = next;
  }

  static String get fullText => lines.value.join('\n');

  static void clear() {
    lines.value = [];
  }
}
