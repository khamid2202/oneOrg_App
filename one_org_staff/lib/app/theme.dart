import 'package:flutter/material.dart';

/// The app's colour system.
///
/// Ported from the web staff app's `shared/theme/ThemeContext.jsx` so the two
/// products offer the same choices under the same names, and a user who picks
/// "Cyan" on the web sees the same cyan here.
///
/// Two independent preferences:
///
/// * **accent** — the brand colour. Drives buttons, the selected nav item, the
///   avatar ring, links and every tinted highlight. Vivid in both modes.
/// * **dark variant** — which shade of dark the app uses *when* dark mode is
///   on. Picking one does not turn dark mode on; the header toggle does that.
///   This mirrors the web exactly.
///
/// Widgets should read accent-tinted surfaces from [AppColors] (a
/// [ThemeExtension]) rather than hardcoding hex values, otherwise changing the
/// accent leaves them stranded on the old colour.

@immutable
class AppAccent {
  const AppAccent({
    required this.key,
    required this.label,
    required this.from,
    required this.to,
    required this.solid,
    required this.softBg,
    required this.softText,
    required this.ring,
    required this.border,
  });

  /// Stable id used for persistence; matches the web's `system_accent` values.
  final String key;
  final String label;

  /// Gradient ends, for surfaces the web paints with `--accent-from/to`.
  final Color from;
  final Color to;

  /// The flat brand colour — buttons, selected states, `ColorScheme.primary`.
  final Color solid;

  /// Pale tinted background and the text that sits on it (light mode values;
  /// [AppColors.resolve] darkens them for dark mode the same way the web does).
  final Color softBg;
  final Color softText;

  final Color ring;
  final Color border;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [from, to],
  );
}

/// The eight selectable accents, in the order the picker shows them.
const List<AppAccent> kAccents = [
  AppAccent(
    key: 'purple',
    label: 'Purple',
    from: Color(0xFF6366F1),
    to: Color(0xFFA855F7),
    solid: Color(0xFF7C3AED),
    softBg: Color(0xFFF5F3FF),
    softText: Color(0xFF6D28D9),
    ring: Color(0xFF8B5CF6),
    border: Color(0xFFDDD6FE),
  ),
  AppAccent(
    key: 'blue',
    label: 'Blue',
    from: Color(0xFF3B82F6),
    to: Color(0xFF2563EB),
    solid: Color(0xFF2563EB),
    softBg: Color(0xFFEFF6FF),
    softText: Color(0xFF1D4ED8),
    ring: Color(0xFF3B82F6),
    border: Color(0xFFBFDBFE),
  ),
  AppAccent(
    key: 'emerald',
    label: 'Emerald',
    from: Color(0xFF10B981),
    to: Color(0xFF059669),
    solid: Color(0xFF059669),
    softBg: Color(0xFFECFDF5),
    softText: Color(0xFF047857),
    ring: Color(0xFF10B981),
    border: Color(0xFFA7F3D0),
  ),
  AppAccent(
    key: 'rose',
    label: 'Rose',
    from: Color(0xFFFB7185),
    to: Color(0xFFE11D48),
    solid: Color(0xFFE11D48),
    softBg: Color(0xFFFFF1F2),
    softText: Color(0xFFBE123C),
    ring: Color(0xFFFB7185),
    border: Color(0xFFFECDD3),
  ),
  AppAccent(
    key: 'amber',
    label: 'Amber',
    from: Color(0xFFF59E0B),
    to: Color(0xFFF97316),
    solid: Color(0xFFEA580C),
    softBg: Color(0xFFFFF7ED),
    softText: Color(0xFFC2410C),
    ring: Color(0xFFFB923C),
    border: Color(0xFFFED7AA),
  ),
  AppAccent(
    key: 'cyan',
    label: 'Cyan',
    from: Color(0xFF06B6D4),
    to: Color(0xFF0891B2),
    solid: Color(0xFF0891B2),
    softBg: Color(0xFFECFEFF),
    softText: Color(0xFF0E7490),
    ring: Color(0xFF22D3EE),
    border: Color(0xFFA5F3FC),
  ),
  AppAccent(
    key: 'pink',
    label: 'Pink',
    from: Color(0xFFEC4899),
    to: Color(0xFFDB2777),
    solid: Color(0xFFDB2777),
    softBg: Color(0xFFFDF2F8),
    softText: Color(0xFFBE185D),
    ring: Color(0xFFF472B6),
    border: Color(0xFFFBCFE8),
  ),
  AppAccent(
    key: 'slate',
    label: 'Slate',
    from: Color(0xFF475569),
    to: Color(0xFF1E293B),
    solid: Color(0xFF334155),
    softBg: Color(0xFFF1F5F9),
    softText: Color(0xFF334155),
    ring: Color(0xFF64748B),
    border: Color(0xFFE2E8F0),
  ),
];

final AppAccent kDefaultAccent = kAccents.first;

/// Looks an accent up by its stored [key], falling back to the default.
AppAccent accentForKey(String? key) {
  for (final accent in kAccents) {
    if (accent.key == key) {
      return accent;
    }
  }
  return kDefaultAccent;
}

@immutable
class AppDarkVariant {
  const AppDarkVariant({
    required this.key,
    required this.label,
    required this.background,
    required this.card,
    required this.line,
  });

  final String key;
  final String label;

  /// Page background for this flavor — the swatch shown in the picker.
  final Color background;

  /// Raised surfaces (cards, sheets, the nav bar) and hairline borders.
  final Color card;
  final Color line;
}

/// The three dark flavors, matching the web's `DARK_VARIANTS` plus the card and
/// line shades its previews use.
const List<AppDarkVariant> kDarkVariants = [
  AppDarkVariant(
    key: 'slate',
    label: 'Slate',
    background: Color(0xFF0F172A),
    card: Color(0xFF1E293B),
    line: Color(0xFF334155),
  ),
  AppDarkVariant(
    key: 'gray',
    label: 'Dark gray',
    background: Color(0xFF18181B),
    card: Color(0xFF27272A),
    line: Color(0xFF3F3F46),
  ),
  AppDarkVariant(
    key: 'black',
    label: 'True black',
    background: Color(0xFF000000),
    card: Color(0xFF171717),
    line: Color(0xFF2E2E2E),
  ),
];

final AppDarkVariant kDefaultDarkVariant = kDarkVariants.first;

AppDarkVariant darkVariantForKey(String? key) {
  for (final variant in kDarkVariants) {
    if (variant.key == key) {
      return variant;
    }
  }
  return kDefaultDarkVariant;
}

/// Accent-derived colours that [ColorScheme] has no slot for.
///
/// Read these instead of hardcoding hex values:
///
/// ```dart
/// final colors = Theme.of(context).extension<AppColors>()!;
/// Container(color: colors.softBg, child: Text('…', style: TextStyle(color: colors.softText)));
/// ```
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accent,
    required this.softBg,
    required this.softText,
    required this.border,
    required this.ring,
    required this.gradient,
    required this.card,
    required this.line,
    required this.mutedText,
  });

  /// The full accent, for the rare case a widget needs `from`/`to` directly.
  final AppAccent accent;

  /// Tinted highlight background and the text/icon colour that reads on it.
  final Color softBg;
  final Color softText;

  /// Hairline border for cards and inputs, and the focus/avatar ring.
  final Color border;
  final Color ring;

  final LinearGradient gradient;

  /// Raised surface and divider for the current mode — in dark these come from
  /// the chosen dark variant, which is what makes True Black actually black.
  final Color card;
  final Color line;

  /// Secondary text (labels, captions, timestamps).
  final Color mutedText;

  /// Builds the extension for one accent + mode. Mirrors the web's
  /// `applyAccent`: the gradient, solid and ring stay vivid in both modes, and
  /// only the *soft* surfaces flip, since a pale -50 tint is unreadable on a
  /// dark card.
  factory AppColors.resolve({
    required AppAccent accent,
    required Brightness brightness,
    required AppDarkVariant darkVariant,
  }) {
    final isDark = brightness == Brightness.dark;

    return AppColors(
      accent: accent,
      softBg: isDark ? accent.solid.withValues(alpha: 0.22) : accent.softBg,
      softText: isDark ? accent.border : accent.softText,
      border: isDark ? accent.ring.withValues(alpha: 0.45) : accent.border,
      ring: accent.ring,
      gradient: accent.gradient,
      card: isDark ? darkVariant.card : Colors.white,
      line: isDark ? darkVariant.line : const Color(0xFFE3EBF4),
      mutedText: isDark ? const Color(0xFF9DB0C1) : const Color(0xFF5C738B),
    );
  }

  @override
  AppColors copyWith({
    AppAccent? accent,
    Color? softBg,
    Color? softText,
    Color? border,
    Color? ring,
    LinearGradient? gradient,
    Color? card,
    Color? line,
    Color? mutedText,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      softBg: softBg ?? this.softBg,
      softText: softText ?? this.softText,
      border: border ?? this.border,
      ring: ring ?? this.ring,
      gradient: gradient ?? this.gradient,
      card: card ?? this.card,
      line: line ?? this.line,
      mutedText: mutedText ?? this.mutedText,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      // The accent itself is a discrete choice, so it snaps at the halfway
      // point rather than interpolating into a colour nobody picked.
      accent: t < 0.5 ? accent : other.accent,
      softBg: Color.lerp(softBg, other.softBg, t)!,
      softText: Color.lerp(softText, other.softText, t)!,
      border: Color.lerp(border, other.border, t)!,
      ring: Color.lerp(ring, other.ring, t)!,
      gradient: LinearGradient.lerp(gradient, other.gradient, t)!,
      card: Color.lerp(card, other.card, t)!,
      line: Color.lerp(line, other.line, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
    );
  }
}

/// Reads [AppColors] for [context].
///
/// Falls back to the default accent when the ambient theme carries no
/// extension — a bare `MaterialApp`, a `Theme` override inside a dialog, or a
/// widget pulled into a test harness. Widgets must not assume the app shell
/// built their theme, so this never returns null and never throws.
AppColors appColorsOf(BuildContext context) {
  final theme = Theme.of(context);
  return theme.extension<AppColors>() ??
      AppColors.resolve(
        accent: kDefaultAccent,
        brightness: theme.brightness,
        darkVariant: kDefaultDarkVariant,
      );
}

/// Builds the [ThemeData] for one accent, brightness and dark flavor.
ThemeData buildAppTheme({
  required AppAccent accent,
  required Brightness brightness,
  required AppDarkVariant darkVariant,
}) {
  final isDark = brightness == Brightness.dark;

  // Seeded from the accent so every Material component (dialogs, snackbars,
  // switches) follows the choice, then `primary` is pinned to the exact accent
  // rather than the tonal approximation the seed algorithm produces.
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: accent.solid,
        brightness: brightness,
      ).copyWith(
        primary: isDark ? accent.ring : accent.solid,
        surface: isDark ? darkVariant.card : Colors.white,
      );

  final colors = AppColors.resolve(
    accent: accent,
    brightness: brightness,
    darkVariant: darkVariant,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    extensions: [colors],
    scaffoldBackgroundColor: isDark
        ? darkVariant.background
        : const Color(0xFFF3F6FB),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? darkVariant.card : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
      ),
    ),
  );
}
