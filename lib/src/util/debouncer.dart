/// A restartable delay used to coalesce rapid-fire input (search typing,
/// quantity-field edits) into a single downstream call.
library;

import 'dart:async';
import 'dart:ui' show VoidCallback;

/// Runs at most one [VoidCallback] per [duration] window: each [run] call
/// cancels any pending action and reschedules, so only the last call within
/// the window actually fires.
class Debouncer {
  /// Creates a debouncer that waits [duration] after the last [run] call
  /// before invoking the action.
  Debouncer({this.duration = const Duration(milliseconds: 300)});

  /// The quiet period a call must survive before it runs.
  final Duration duration;

  Timer? _timer;

  /// Schedules [action], cancelling any not-yet-fired action from a
  /// previous [run] call.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Cancels a pending action without scheduling a new one.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Cancels any pending action. Safe to call more than once.
  void dispose() => cancel();
}
