import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Panel dengan efek kaca buram (glassmorphism).
///
/// [BackdropFilter] mengaburkan apa pun yang berada di belakang widget ini,
/// lalu lapisan putih semi transparan dan garis tepi tipis ditambahkan agar
/// permukaannya terlihat seperti kaca.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final double blur;
  final double opasitas;
  final VoidCallback? onTap;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    BorderRadius? radius,
    this.blur = 24,
    this.opasitas = 0.07,
    this.onTap,
  }) : radius = radius ?? const BorderRadius.all(Radius.circular(22));

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.kacaIsi(opasitas),
            borderRadius: radius,
            border: Border.all(color: AppTheme.kacaTepi),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Latar belakang berwarna yang menjadi "isi" di balik panel kaca.
///
/// Tanpa latar yang berwarna, efek blur tidak akan terlihat karena tidak ada
/// yang dapat dikaburkan.
class AuroraBackground extends StatelessWidget {
  final List<Color> warna;

  const AuroraBackground({
    super.key,
    this.warna = const [AppTheme.aksen, Color(0xFF7B2FF7), Color(0xFF00C2A8)],
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: AppTheme.latar)),
          _noda(alignment: const Alignment(-1.1, -0.9), warna: warna[0], ukuran: 330),
          _noda(alignment: const Alignment(1.2, -0.55), warna: warna[1], ukuran: 300),
          _noda(alignment: const Alignment(-0.6, 0.85), warna: warna[2], ukuran: 280),
        ],
      ),
    );
  }

  Widget _noda({
    required Alignment alignment,
    required Color warna,
    required double ukuran,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: ukuran,
        height: ukuran,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [warna.withOpacity(0.55), warna.withOpacity(0)],
          ),
        ),
      ),
    );
  }
}
