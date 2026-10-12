import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/locale_provider.dart';
import '../core/text_scale_provider.dart';
import '../core/theme_option_provider.dart';
import '../l10n/app_localizations.dart';
import 'responsive.dart';
import 'router.dart';
import 'text_scaling.dart';
import 'theme.dart';

class AnToanApp extends ConsumerWidget {
  const AnToanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final appTextFactor = ref.watch(textScaleProvider).factor;
    final themeOption = ref.watch(themeOptionProvider);

    // `system` (the default -- see ThemeOptionNotifier) hands light/dark and
    // OS-brightness tracking straight to Flutter's own themeMode: system,
    // unchanged from the app's behavior before this setting existed. Light,
    // dark and sepia are explicit overrides: both theme/darkTheme slots get
    // the same ThemeData and themeMode is forced, so Flutter never
    // second-guesses the choice with the OS setting. Sepia has no native
    // Flutter ThemeMode, so it's modeled as its own forced ThemeData rather
    // than bolted onto the light/dark slots.
    final (ThemeData theme, ThemeData darkTheme, ThemeMode themeMode) = switch (themeOption) {
      AppThemeOption.system => (
          buildTheme(Brightness.light),
          buildTheme(Brightness.dark),
          ThemeMode.system,
        ),
      AppThemeOption.light => (
          buildTheme(Brightness.light),
          buildTheme(Brightness.light),
          ThemeMode.light,
        ),
      AppThemeOption.dark => (
          buildTheme(Brightness.dark),
          buildTheme(Brightness.dark),
          ThemeMode.dark,
        ),
      AppThemeOption.sepia => (buildSepiaTheme(), buildSepiaTheme(), ThemeMode.light),
    };

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Applies the app's own text-size setting on top of the OS setting for
      // the whole app, clamped overall -- see text_scaling.dart.
      builder: (context, child) {
        final ambient = MediaQuery.textScalerOf(context);
        final scaled = MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: combinedTextScaler(ambient, appTextFactor)),
          child: child!,
        );
        return ResponsiveMaxWidth(child: scaled);
      },
      routerConfig: ref.watch(routerProvider),
    );
  }
}
