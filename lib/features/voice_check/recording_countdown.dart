/// Longest a single recording may run (CLAUDE.md: cap the length).
const maxListenDuration = Duration(seconds: 60);

/// Counts recording time, one tick per second, and says when the cap is hit.
/// Plain Dart so the cap logic can be unit-tested without real timers.
class ListenCountdown {
  ListenCountdown({this.limit = maxListenDuration});

  final Duration limit;
  int _elapsed = 0;

  int get elapsedSeconds => _elapsed;
  int get secondsLeft => limit.inSeconds - _elapsed;
  bool get reachedCap => _elapsed >= limit.inSeconds;
  double get progress => _elapsed / limit.inSeconds;

  /// Adds one second. Returns true only on the tick that reaches the cap.
  bool tick() {
    if (reachedCap) return false;
    _elapsed++;
    return reachedCap;
  }

  void reset() => _elapsed = 0;
}
