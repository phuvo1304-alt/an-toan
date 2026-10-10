import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/locale_provider.dart';
import '../core/text_scale_provider.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'text_scaling.dart';
import 'theme.dart';

class AnToanApp extends ConsumerWidget {
  const AnToanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final appTextFactor = ref.watch(textScaleProvider).factor;
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
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
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: combinedTextScaler(ambient, appTextFactor)),
          child: child!,
        );
      },
      routerConfig: ref.watch(routerProvider),
    );
  }
}
