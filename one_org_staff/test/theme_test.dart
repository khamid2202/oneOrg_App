import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/app/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('accent lookup', () {
    test('falls back to the default for an unknown or missing key', () {
      expect(accentForKey(null).key, kDefaultAccent.key);
      expect(accentForKey('chartreuse').key, kDefaultAccent.key);
      expect(accentForKey('cyan').label, 'Cyan');
    });

    test('offers the web palette minus amber', () {
      // Amber was dropped on purpose: it is the one accent that reads as a
      // warning colour, so it is a deliberate divergence from the web's eight.
      expect(kAccents.map((a) => a.key), const [
        'purple',
        'blue',
        'emerald',
        'rose',
        'cyan',
        'pink',
        'slate',
      ]);
      expect(accentForKey('amber').key, kDefaultAccent.key);
    });

    test('offers the three web dark flavors', () {
      expect(kDarkVariants.map((v) => v.label), const [
        'Slate',
        'Dark gray',
        'True black',
      ]);
      expect(darkVariantForKey('black').background, const Color(0xFF000000));
    });
  });

  group('ThemeController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('starts on the defaults when nothing is stored', () async {
      final controller = ThemeController();
      await controller.load();

      expect(controller.accent.key, 'purple');
      expect(controller.darkVariant.key, 'slate');
      expect(controller.themeMode, ThemeMode.light);
    });

    test('restores what was stored, under the web app\'s keys', () async {
      SharedPreferences.setMockInitialValues({
        ThemeController.accentKeyPref: 'cyan',
        ThemeController.themeModePref: 'dark',
        ThemeController.darkVariantPref: 'black',
      });

      final controller = ThemeController();
      await controller.load();

      expect(controller.accent.key, 'cyan');
      expect(controller.isDark, isTrue);
      expect(controller.darkVariant.key, 'black');
    });

    test('persists a chosen accent so it survives a restart', () async {
      final controller = ThemeController();
      await controller.load();
      await controller.setAccent(accentForKey('emerald'));

      final reloaded = ThemeController();
      await reloaded.load();

      expect(reloaded.accent.key, 'emerald');
    });

    test('picking a dark flavor does not switch the app into dark', () async {
      // Matches the web: the flavor is only which shade dark mode uses.
      final controller = ThemeController();
      await controller.load();

      await controller.setDarkVariant(darkVariantForKey('gray'));

      expect(controller.darkVariant.key, 'gray');
      expect(controller.themeMode, ThemeMode.light);
    });

    test('notifies listeners so the running app recolours', () async {
      final controller = ThemeController();
      await controller.load();

      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.setAccent(accentForKey('rose'));
      await controller.toggleThemeMode();

      expect(notifications, 2);
    });
  });

  group('buildAppTheme', () {
    test('drives ColorScheme.primary from the chosen accent', () {
      final light = buildAppTheme(
        accent: accentForKey('emerald'),
        brightness: Brightness.light,
        darkVariant: kDefaultDarkVariant,
      );

      expect(light.colorScheme.primary, accentForKey('emerald').solid);
    });

    test('the dark flavor sets the page background', () {
      final black = buildAppTheme(
        accent: kDefaultAccent,
        brightness: Brightness.dark,
        darkVariant: darkVariantForKey('black'),
      );
      final slate = buildAppTheme(
        accent: kDefaultAccent,
        brightness: Brightness.dark,
        darkVariant: darkVariantForKey('slate'),
      );

      expect(black.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(slate.scaffoldBackgroundColor, const Color(0xFF0F172A));
    });

    test('exposes AppColors, and soft surfaces flip for dark', () {
      final accent = accentForKey('cyan');
      final light = buildAppTheme(
        accent: accent,
        brightness: Brightness.light,
        darkVariant: kDefaultDarkVariant,
      ).extension<AppColors>()!;
      final dark = buildAppTheme(
        accent: accent,
        brightness: Brightness.dark,
        darkVariant: kDefaultDarkVariant,
      ).extension<AppColors>()!;

      // Light uses the pale -50 tint; dark can't, so it tints the solid.
      expect(light.softBg, accent.softBg);
      expect(dark.softBg, isNot(accent.softBg));

      // The ring stays vivid in both, as on the web.
      expect(light.ring, accent.ring);
      expect(dark.ring, accent.ring);
    });
  });

  testWidgets('appColorsOf falls back when the theme carries no extension', (
    tester,
  ) async {
    // Widgets get dropped into bare MaterialApps — test harnesses, dialogs with
    // a Theme override. Reading the extension with `!` crashed there.
    late AppColors colors;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            colors = appColorsOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(colors.accent.key, kDefaultAccent.key);
    expect(colors.card, Colors.white);
  });

  testWidgets('appColorsOf follows the ambient brightness in a bare app', (
    tester,
  ) async {
    late AppColors colors;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(
          builder: (context) {
            colors = appColorsOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(colors.card, kDefaultDarkVariant.card);
  });

  testWidgets('changing the accent recolours the running app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController();
    await controller.load();

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: controller,
        builder: (context, _) => MaterialApp(
          theme: buildAppTheme(
            accent: controller.accent,
            brightness: Brightness.light,
            darkVariant: controller.darkVariant,
          ),
          home: Builder(
            builder: (context) => Text(
              'x',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
      ),
    );

    Color shownColor() => tester.widget<Text>(find.text('x')).style!.color!;

    expect(shownColor(), accentForKey('purple').solid);

    await controller.setAccent(accentForKey('pink'));
    await tester.pumpAndSettle();

    expect(shownColor(), accentForKey('pink').solid);
  });
}
