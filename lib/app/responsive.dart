import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// This UI was built mobile-first (phones, and the Android/iOS apps). The web
// build is additive -- on a real phone browser nothing here changes anything
// (the breakpoint never triggers below it). On a wide desktop browser window,
// without this the 4 home cards / result screen / everything else would
// stretch edge-to-edge across the whole window, which looks broken, not
// "responsive". Constrains the whole app to a comfortable mobile-app-width
// column, centered, on anything wider than a phone.
// ---------------------------------------------------------------------------

/// Below this width, nothing changes -- an actual phone browser (portrait or
/// landscape) never hits this, only a desktop/tablet-width window does.
const double kWideScreenBreakpoint = 600;

/// The column width used above the breakpoint: comfortable mobile-app width,
/// not a cramped phone width and not a desktop-reading-width column either --
/// this is still the same mobile-first UI, just centered instead of
/// stretched.
const double kContentMaxWidth = 480;

/// Wraps the whole app (every route, via MaterialApp's `builder:`) so it
/// never has to be applied per-screen. Below [kWideScreenBreakpoint], this is
/// a no-op -- `child` renders exactly as it always has.
class ResponsiveMaxWidth extends StatelessWidget {
  final Widget child;
  const ResponsiveMaxWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= kWideScreenBreakpoint) return child;

    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      // A neutral backdrop distinct from the in-app surface, so the centered
      // column reads as "the app, on a wide window" rather than looking like
      // a layout bug with empty space on both sides.
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
          child: Material(
            // Re-establishes the app's own background for the column itself
            // (ColoredBox above is only the outer backdrop).
            color: scheme.surface,
            child: child,
          ),
        ),
      ),
    );
  }
}
