import 'package:flutter/foundation.dart';

typedef MonotonicNow = Duration Function();

class CodexMonotonicClock {
  CodexMonotonicClock._();

  static final Stopwatch _stopwatch = Stopwatch()..start();
  static MonotonicNow _now = _defaultNow;

  static Duration now() => _now();

  static Duration _defaultNow() => _stopwatch.elapsed;

  @visibleForTesting
  static void debugSetNowProvider(MonotonicNow? provider) {
    _now = provider ?? _defaultNow;
  }
}
