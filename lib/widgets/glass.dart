import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/pengaturan_service.dart';
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
///
/// Sejak versi UAS, tiga gumpalan warna bergerak perlahan mengikuti lintasan
/// sinus dan sedikit membesar-mengecil, sehingga latar terasa "hidup".
/// Gerakan dapat dimatikan lewat halaman Akun untuk menghemat baterai.
class AuroraBackground extends StatefulWidget {
  final List<Color> warna;

  const AuroraBackground({
    super.key,
    this.warna = const [AppTheme.aksen, Color(0xFF7B2FF7), Color(0xFF00C2A8)],
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  /// Satu putaran penuh gerakan berlangsung 30 detik lalu berulang.
  late final AnimationController _animasi = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  );

  /// Posisi dasar, ukuran, dan "watak" gerakan tiap gumpalan. Frekuensi
  /// dibuat bilangan bulat agar akhir putaran menyambung mulus ke awal.
  static const _noda = [
    (x: -1.1, y: -0.9, ukuran: 330.0, fx: 1, fy: 2, fase: 0.0),
    (x: 1.2, y: -0.55, ukuran: 300.0, fx: 2, fy: 1, fase: 2.1),
    (x: -0.6, y: 0.85, ukuran: 280.0, fx: 1, fy: 1, fase: 4.2),
  ];

  /// Posisi gerakan yang benar-benar dipakai untuk menggambar.
  ///
  /// Gumpalan bergerak sangat pelan, sehingga cukup digambar ulang setiap
  /// 5 frame (±12 kali per detik) dan perbedaannya hampir tidak terlihat.
  /// Ini penting karena setiap kali latar digambar ulang, semua panel kaca
  /// di atasnya ikut menghitung ulang efek blur.
  final ValueNotifier<double> _fase = ValueNotifier<double>(0);
  int _hitungFrame = 0;

  @override
  void initState() {
    super.initState();
    _animasi.addListener(() {
      if (++_hitungFrame % 5 == 0) _fase.value = _animasi.value;
    });
    _sesuaikan();
    latarBergerak.addListener(_sesuaikan);
    sedangMenggulir.addListener(_sesuaikan);
  }

  @override
  void dispose() {
    latarBergerak.removeListener(_sesuaikan);
    sedangMenggulir.removeListener(_sesuaikan);
    _animasi.dispose();
    _fase.dispose();
    super.dispose();
  }

  /// Aurora hanya bergerak bila diizinkan di pengaturan DAN layar sedang
  /// tidak digulir. Saat digulir, setiap panel kaca sudah menghitung ulang
  /// blur di setiap frame, sehingga gerakan aurora hanya menambah beban.
  void _sesuaikan() {
    if (latarBergerak.value && !sedangMenggulir.value) {
      _animasi.repeat();
    } else {
      _animasi.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // RepaintBoundary memisahkan lapisan latar agar gerakannya tidak
      // memaksa widget lain ikut digambar ulang.
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _fase,
          builder: (context, _) {
            final t = _fase.value * 2 * math.pi;
            return Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: AppTheme.latar)),
                for (var i = 0; i < _noda.length; i++)
                  _gumpalan(
                    alignment: Alignment(
                      _noda[i].x +
                          0.35 * math.sin(t * _noda[i].fx + _noda[i].fase),
                      _noda[i].y +
                          0.25 * math.cos(t * _noda[i].fy + _noda[i].fase),
                    ),
                    warna: widget.warna[i % widget.warna.length],
                    ukuran: _noda[i].ukuran *
                        (1 + 0.12 * math.sin(t + _noda[i].fase)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _gumpalan({
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
