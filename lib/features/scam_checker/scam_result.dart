enum RiskLevel { safe, suspicious, likelyScam }

class RedFlag {
  final String title;
  final String explanation;
  final String quote;

  const RedFlag({
    required this.title,
    required this.explanation,
    required this.quote,
  });

  factory RedFlag.fromJson(Map<String, dynamic> json) => RedFlag(
        title: (json['title'] ?? '').toString(),
        explanation: (json['explanation'] ?? '').toString(),
        quote: (json['quote'] ?? '').toString(),
      );
}

/// What the Edge Function returns. Parsing is defensive: if a field is
/// missing or odd we fall back to a safe default instead of crashing.
class ScamResult {
  final RiskLevel riskLevel;
  final int riskScore;
  final String summary;
  final List<RedFlag> redFlags;
  final List<String> whatToDo;
  final String scamType;
  final String confidenceNote;
  final String language;

  const ScamResult({
    required this.riskLevel,
    required this.riskScore,
    required this.summary,
    required this.redFlags,
    required this.whatToDo,
    required this.scamType,
    required this.confidenceNote,
    required this.language,
  });

  static RiskLevel _parseLevel(Object? v) {
    switch (v) {
      case 'safe':
        return RiskLevel.safe;
      case 'likely_scam':
        return RiskLevel.likelyScam;
      default:
        // Unknown value: be cautious, never assume safe.
        return RiskLevel.suspicious;
    }
  }

  factory ScamResult.fromJson(Map<String, dynamic> json) {
    final flags = json['red_flags'];
    final steps = json['what_to_do'];
    final score = json['risk_score'];
    return ScamResult(
      riskLevel: _parseLevel(json['risk_level']),
      riskScore: (score is num ? score.round() : 50).clamp(0, 100),
      summary: (json['summary'] ?? '').toString(),
      redFlags: flags is List
          ? flags
              .whereType<Map>()
              .map((f) => RedFlag.fromJson(Map<String, dynamic>.from(f)))
              .toList()
          : const [],
      whatToDo: steps is List ? steps.map((s) => s.toString()).toList() : const [],
      scamType: (json['scam_type'] ?? 'other').toString(),
      confidenceNote: (json['confidence_note'] ?? '').toString(),
      language: (json['language'] ?? 'vi').toString(),
    );
  }
}
