import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:an_toan/app/app.dart';
import 'package:an_toan/app/router.dart';
import 'package:an_toan/core/onboarding_provider.dart';

void main() {
  group('OnboardingNotifier', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to false', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(onboardingProvider), isFalse);
      await container.read(onboardingProvider.notifier).loaded;
      expect(container.read(onboardingProvider), isFalse); // nothing saved yet
    });

    test('markComplete() sets true and persists across a fresh provider', () async {
      final first = ProviderContainer();
      final notifier = first.read(onboardingProvider.notifier);
      await notifier.loaded;
      await notifier.markComplete();
      expect(first.read(onboardingProvider), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_complete'), isTrue);
      first.dispose();

      // A brand-new provider instance, same shared_preferences.
      final second = ProviderContainer();
      addTearDown(second.dispose);
      await second.read(onboardingProvider.notifier).loaded;
      expect(second.read(onboardingProvider), isTrue);
    });
  });

  testWidgets('fresh app shows onboarding first, then lands on Home', (tester) async {
    SharedPreferences.setMockInitialValues({}); // onboarding_complete unset
    await tester.pumpWidget(const ProviderScope(child: AnToanApp()));
    await tester.pumpAndSettle();

    // Slide 1 (Vietnamese is the default), not Home.
    expect(find.text('An Toàn'), findsOneWidget);
    expect(find.text('Đố vui'), findsNothing); // a Home card

    // Slide 2: language. Switch to English to check the choice is applied.
    await tester.tap(find.text('Tiếp'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn ngôn ngữ'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your language'), findsOneWidget);

    // Slide 3: privacy note + Get started.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Your privacy'), findsOneWidget);
    expect(find.textContaining('sent to an AI service'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Home, in English, and the flag is saved.
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_complete'), isTrue);
    expect(prefs.getString('language'), 'en');
  });

  testWidgets('Skip jumps to the privacy slide instead of skipping it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: AnToanApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(find.text('Quyền riêng tư của bạn'), findsOneWidget);
    expect(find.text('Bắt đầu sử dụng'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_complete'), isNull); // not completed by Skip
  });

  testWidgets('a returning user starts on Home and cannot open /onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    // Same as main(): the saved flag is known before the first frame.
    await tester.pumpWidget(ProviderScope(
      overrides: [onboardingInitialValueProvider.overrideWithValue(true)],
      child: const AnToanApp(),
    ));
    await tester.pump(); // first frame only: no flash of onboarding
    expect(find.text('Đố vui'), findsOneWidget);
    expect(find.text('Bỏ qua'), findsNothing);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    final router = ProviderScope.containerOf(context).read(routerProvider);
    router.go('/onboarding');
    await tester.pumpAndSettle();
    expect(find.text('Đố vui'), findsOneWidget); // redirected back to Home
  });
}
