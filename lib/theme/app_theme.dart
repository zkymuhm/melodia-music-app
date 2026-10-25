import 'package:flutter/material.dart';

/// Kumpulan warna dan gaya yang dipakai seluruh aplikasi, disusun menyerupai
/// tampilan Apple Music: latar gelap pekat, aksen merah muda, dan permukaan
/// kaca semi transparan.
class AppTheme {
  const AppTheme._();

  /// Warna aksen khas Apple Music.
  static const Color aksen = Color(0xFFFA2D48);
  static const Color latar = Color(0xFF07070A);
  static const Color latarLembut = Color(0xFF131318);

  /// Warna isi panel kaca beserta garis tepinya.
  static Color kacaIsi(double opasitas) => Colors.white.withOpacity(opasitas);
  static Color get kacaTepi => Colors.white.withOpacity(0.14);

  static ThemeData get gelap {
    final skema = ColorScheme.fromSeed(
      seedColor: aksen,
      brightness: Brightness.dark,
    ).copyWith(
      primary: aksen,
      surface: latar,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: skema,
      scaffoldBackgroundColor: latar,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        // Judul besar bergaya "Large Title" pada iOS.
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
        bodySmall: TextStyle(fontSize: 12, color: Colors.white54),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 5,
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
    );
  }
}
