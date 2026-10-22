import '../../l10n/app_localizations.dart';
import 'scam_api.dart';

/// The friendly, localized message for each analyze-scam error. Shared by the
/// Scam Checker and the Voice check screen so the two cannot drift apart.
String scamErrorText(ScamError e, AppLocalizations t) {
  switch (e) {
    case ScamError.notConfigured:
      return t.errorNotConfigured;
    case ScamError.empty:
      return t.errorEmpty;
    case ScamError.tooLong:
      return t.errorTooLong;
    case ScamError.imageTooLarge:
      return t.errorImageTooLarge;
    case ScamError.tooManyImages:
      return t.errorTooManyImages;
    case ScamError.unsupportedImage:
      return t.imageUnsupported;
    case ScamError.rateLimited:
      return t.errorRateLimited;
    case ScamError.network:
      return t.errorNetwork;
    case ScamError.generic:
      return t.errorGeneric;
  }
}
