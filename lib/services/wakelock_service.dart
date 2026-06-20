import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class WakelockService {
  WakelockService._();

  static void apply(bool enabled) {
    final future = enabled ? WakelockPlus.enable() : WakelockPlus.disable();
    future.catchError((Object error, StackTrace stackTrace) {
      if (kDebugMode) {
        debugPrint('Wakelock request failed: $error');
      }
    });
  }
}
