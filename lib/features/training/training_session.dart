import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'training_data.dart';

/// The state of one training attempt. Immutable: every change makes a new copy,
/// which is what tells Riverpod to rebuild the screen.
class TrainingSessionState {
  final TrainingScenario? scenario; // null = no scenario opened yet
  final Set<String> tapped; // ids of the segments the user marked
  final bool submitted;

  const TrainingSessionState({
    required this.scenario,
    required this.tapped,
    required this.submitted,
  });

  static const empty =
      TrainingSessionState(scenario: null, tapped: {}, submitted: false);

  Iterable<ScenarioSegment> get _segments => scenario?.segments ?? const [];

  /// Suspicious segments the user found.
  Set<String> get caught => {
        for (final s in _segments)
          if (s.isSuspicious && tapped.contains(s.id)) s.id,
      };

  /// Suspicious segments the user did not tap.
  Set<String> get missed => {
        for (final s in _segments)
          if (s.isSuspicious && !tapped.contains(s.id)) s.id,
      };

  /// Normal segments the user wrongly marked.
  Set<String> get falsePositives => {
        for (final s in _segments)
          if (!s.isSuspicious && tapped.contains(s.id)) s.id,
      };

  int get suspiciousCount => _segments.where((s) => s.isSuspicious).length;
}

/// Interaction state for Training Mode: which segments are marked, and
/// whether the answer was submitted. Same shape as QuizSession (answer once,
/// then locked), as a Riverpod Notifier.
class TrainingSessionNotifier extends Notifier<TrainingSessionState> {
  @override
  TrainingSessionState build() => TrainingSessionState.empty;

  /// Opens a scenario with nothing marked.
  void start(TrainingScenario scenario) {
    state = TrainingSessionState(scenario: scenario, tapped: const {}, submitted: false);
  }

  /// Marks or unmarks a segment. Does nothing after submit, or for an id that
  /// is not in the current scenario.
  void toggleSegment(String id) {
    final scenario = state.scenario;
    if (scenario == null || state.submitted) return;
    if (!scenario.segments.any((s) => s.id == id)) return;
    final tapped = {...state.tapped};
    if (!tapped.remove(id)) tapped.add(id);
    state = TrainingSessionState(scenario: scenario, tapped: tapped, submitted: false);
  }

  /// Locks the answer. caught / missed / falsePositives are then read from state.
  void submit() {
    if (state.scenario == null || state.submitted) return;
    state = TrainingSessionState(
        scenario: state.scenario, tapped: state.tapped, submitted: true);
  }

  /// Try the same scenario again from scratch.
  void reset() {
    final scenario = state.scenario;
    state = scenario == null ? TrainingSessionState.empty : TrainingSessionState(
        scenario: scenario, tapped: const {}, submitted: false);
  }
}

final trainingSessionProvider =
    NotifierProvider<TrainingSessionNotifier, TrainingSessionState>(
        TrainingSessionNotifier.new);
