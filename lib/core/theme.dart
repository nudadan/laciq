import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

/// Sistem desain LaciQ: gelap-dulu, aksen elektrik cyan-violet,
/// sudut sangat membulat, angka besar bergaya teknis.
///
/// Semua warna dan bentuk dikendalikan dari sini agar seluruh layar konsisten.
/// Warna makna keuangan (pemasukan/pengeluaran/transfer) ada di [AppPalette],
/// bukan di ColorScheme Material.

const _display = 'SpaceGrotesk'; // judul dan angka
const _body = 'PlusJakartaSans'; // teks biasa

/// Bilah status dan navigasi sistem transparan, ikonnya menyesuaikan tema.
/// contrastEnforced=false mematikan lapisan abu-abu otomatis Android.
///
/// Harus juga dipasang di AppBarTheme: AppBar memasang gayanya sendiri dan
/// menimpa AnnotatedRegion di atasnya. Dengan latar transparan ia menebak
/// "gelap" dan memakai ikon putih, sehingga tak terbaca di mode terang.
SystemUiOverlayStyle systemBarsStyle(Brightness b) {
  final iconBrightness = b == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    statusBarBrightness: b,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
    systemNavigationBarContrastEnforced: false,
  );
}

// ---------------------------------------------------------------- palet

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.warning,
    required this.heroGradient,
    required this.glow,
  });

  final Color income;
  final Color expense;
  final Color transfer;
  final Color warning;

  /// Gradien kartu utama dan tombol aksi.
  final List<Color> heroGradient;

  /// Warna cahaya di sekitar elemen aksen.
  final Color glow;

  @override
  AppPalette copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
    Color? warning,
    List<Color>? heroGradient,
    Color? glow,
  }) => AppPalette(
    income: income ?? this.income,
    expense: expense ?? this.expense,
    transfer: transfer ?? this.transfer,
    warning: warning ?? this.warning,
    heroGradient: heroGradient ?? this.heroGradient,
    glow: glow ?? this.glow,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      heroGradient: [
        for (var i = 0; i < heroGradient.length; i++)
          Color.lerp(heroGradient[i], other.heroGradient[i], t)!,
      ],
      glow: Color.lerp(glow, other.glow, t)!,
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// Ujung cyan sengaja tidak terlalu terang agar teks putih tetap terbaca (>= 3:1).
const _heroGradient = [Color(0xFF3B5BFF), Color(0xFF7C3AED), Color(0xFF0891B2)];

const _darkPalette = AppPalette(
  income: Color(0xFF34E0A1),
  expense: Color(0xFFFF6B81),
  transfer: Color(0xFF22D3EE),
  warning: Color(0xFFFFB454),
  heroGradient: _heroGradient,
  glow: Color(0xFF6D5BFF),
);

// Warna makna di mode terang digelapkan agar lolos kontras 4,5:1 sebagai teks
// kecil di atas kartu putih maupun latar halaman (dijaga test/theme_test.dart).
const _lightPalette = AppPalette(
  income: Color(0xFF047857),
  expense: Color(0xFFC81E45),
  transfer: Color(0xFF0E7490),
  warning: Color(0xFFB45309),
  heroGradient: _heroGradient,
  glow: Color(0xFF7C6BFF),
);

// ------------------------------------------------------- skema warna

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF8C9EFF),
  onPrimary: Color(0xFF0B1020),
  primaryContainer: Color(0xFF262F66),
  onPrimaryContainer: Color(0xFFDDE3FF),
  secondary: Color(0xFF22D3EE),
  onSecondary: Color(0xFF00363D),
  secondaryContainer: Color(0xFF0B3B47),
  onSecondaryContainer: Color(0xFFB8F0FA),
  tertiary: Color(0xFFB794F6),
  onTertiary: Color(0xFF2A1250),
  error: Color(0xFFFF6B81),
  onError: Color(0xFF3B0A14),
  errorContainer: Color(0xFF5A1826),
  onErrorContainer: Color(0xFFFFD9DE),
  surface: Color(0xFF0A0E1A),
  onSurface: Color(0xFFE8ECF8),
  onSurfaceVariant: Color(0xFF9AA5C4),
  surfaceContainerLowest: Color(0xFF070A14),
  surfaceContainerLow: Color(0xFF0F1526),
  surfaceContainer: Color(0xFF141B2E),
  surfaceContainerHigh: Color(0xFF1A2238),
  surfaceContainerHighest: Color(0xFF222C47),
  outline: Color(0xFF7280A3),
  outlineVariant: Color(0xFF232C45),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF4F46E5),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFE0E4FF),
  onPrimaryContainer: Color(0xFF141B6B),
  secondary: Color(0xFF0891B2),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFCFF4FC),
  onSecondaryContainer: Color(0xFF00363D),
  tertiary: Color(0xFF7C3AED),
  onTertiary: Color(0xFFFFFFFF),
  error: Color(0xFFC81E45),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFD9DE),
  onErrorContainer: Color(0xFF5A1826),
  surface: Color(0xFFF3F5FF),
  onSurface: Color(0xFF0F1530),
  onSurfaceVariant: Color(0xFF5A6488),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFFFFFF),
  surfaceContainer: Color(0xFFF7F8FF),
  surfaceContainerHigh: Color(0xFFEBEEFC),
  surfaceContainerHighest: Color(0xFFE1E6F8),
  outline: Color(0xFF6E7899),
  outlineVariant: Color(0xFFDDE2F5),
  shadow: Color(0xFF1B2250),
  scrim: Color(0xFF000000),
);

// ---------------------------------------------------------- tipografi

FontWeight _fw(double w) =>
    FontWeight.values[(w / 100).round().clamp(1, 9) - 1];

/// [wght] diterapkan lewat FontVariation karena font-nya variabel; FontWeight
/// diisi sepadan agar `copyWith(fontWeight: ...)` di kode lain tetap masuk akal.
TextStyle _t(
  String family,
  double size,
  double wght, {
  double? height,
  double? spacing,
}) => TextStyle(
  fontFamily: family,
  fontSize: size,
  height: height,
  letterSpacing: spacing,
  fontWeight: _fw(wght),
  fontVariations: [FontVariation('wght', wght)],
);

final _textTheme = TextTheme(
  displayLarge: _t(_display, 57, 600, height: 1.1, spacing: -1),
  displayMedium: _t(_display, 45, 600, height: 1.1, spacing: -0.5),
  displaySmall: _t(_display, 36, 600, height: 1.15, spacing: -0.5),
  headlineLarge: _t(_display, 32, 600, height: 1.2, spacing: -0.3),
  headlineMedium: _t(_display, 28, 600, height: 1.2, spacing: -0.2),
  headlineSmall: _t(_display, 24, 600, height: 1.25),
  titleLarge: _t(_display, 22, 600, height: 1.25),
  titleMedium: _t(_body, 16, 600, height: 1.3),
  titleSmall: _t(_body, 14, 600, height: 1.3),
  bodyLarge: _t(_body, 16, 400, height: 1.45),
  bodyMedium: _t(_body, 14, 400, height: 1.45),
  bodySmall: _t(_body, 12, 400, height: 1.4),
  labelLarge: _t(_body, 14, 600, height: 1.3),
  labelMedium: _t(_body, 12, 600, height: 1.3),
  labelSmall: _t(_body, 11, 600, height: 1.3),
);

// ---------------------------------------------------------------- tema

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark ? _darkScheme : _lightScheme;
  final palette = dark ? _darkPalette : _lightPalette;
  final text = _textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  const stadium = StadiumBorder();
  RoundedRectangleBorder rounded(
    double r, {
    BorderSide side = BorderSide.none,
  }) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(r),
    side: side,
  );

  OutlineInputBorder field(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: color == Colors.transparent
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surfaceContainerHigh, // menu DropdownButton
    fontFamily: _body,
    textTheme: text,
    extensions: [palette],
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      systemOverlayStyle: systemBarsStyle(brightness),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: rounded(24, side: BorderSide(color: scheme.outlineVariant)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: rounded(28),
      titleTextStyle: text.titleLarge,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: rounded(18),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.surfaceContainerHighest,
      contentTextStyle: text.bodyMedium,
      actionTextColor: scheme.primary,
      shape: rounded(16),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: field(Colors.transparent),
      enabledBorder: field(Colors.transparent),
      disabledBorder: field(Colors.transparent),
      focusedBorder: field(scheme.primary, width: 1.6),
      errorBorder: field(scheme.error),
      focusedErrorBorder: field(scheme.error, width: 1.6),
      labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      hintStyle: text.bodyMedium?.copyWith(color: scheme.outline),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: stadium,
        textStyle: text.labelLarge?.copyWith(fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: stadium,
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        textStyle: text.labelLarge?.copyWith(fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: stadium),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: stadium,
      elevation: 0,
      extendedTextStyle: text.labelLarge?.copyWith(fontSize: 15),
    ),
    chipTheme: ChipThemeData(
      shape: stadium,
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primary.withValues(alpha: 0.22),
      labelStyle: text.labelLarge,
      checkmarkColor: scheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: stadium,
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerHigh,
        selectedBackgroundColor: scheme.primary.withValues(alpha: 0.22),
        selectedForegroundColor: scheme.onSurface,
        foregroundColor: scheme.onSurfaceVariant,
        textStyle: text.labelLarge,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: scheme.primary.withValues(alpha: 0.20),
      indicatorShape: stadium,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return text.labelSmall?.copyWith(
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: Colors.transparent,
      labelStyle: text.labelLarge,
      unselectedLabelStyle: text.labelLarge,
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorSize: TabBarIndicatorSize.label,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
      linearMinHeight: 8,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      subtitleTextStyle: text.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}
