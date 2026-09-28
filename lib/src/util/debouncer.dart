/// Collapses a burst of calls into a single trailing invocation.
///
/// Used by [SearchField] to turn every keystroke into at most one
/// [onChanged] call per [duration] of typing pause, so a server search
/// endpoint sees one request per pause rather than one per keystroke.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 300)});

  final Duration duration;
  Timer? _timer;

  /// Schedules [action] to run after [duration] of no further [run] calls.
  /// A call within the window cancels the previously scheduled one, so only
  /// the last [action] passed within a window actually runs.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Cancels a pending [run] without scheduling anything new.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Cancels any pending action. Call from the owning [State.dispose].
  void dispose() => cancel();
}
