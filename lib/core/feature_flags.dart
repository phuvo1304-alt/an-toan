import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';

/// Whether the Voice scam detection card and the /voice route are shown.
/// A provider so tests can switch it; the real value is the compile-time
/// flag in [AppConfig].
final voiceScamEnabledProvider = Provider<bool>((ref) => AppConfig.voiceScamEnabled);
