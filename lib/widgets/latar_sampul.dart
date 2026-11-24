import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/pengaturan_service.dart';
import '../theme/app_theme.dart';

/// Latar yang warnanya mengikuti sampul lagu, seperti plugin Beautiful
/// Lyrics di Spotify.
///
/// Agar ringan, sampul TIDAK dikaburkan setiap frame. Sampul dimuat sekali
/// dalam ukuran sangat kecil (24 px), dikaburkan sekali menjadi gambar
/// 128 px, lalu gambar jadi itu cukup diperbesar dan diputar. Memutar gambar
/// yang sudah jadi hampir tidak membebani GPU, berbeda dengan efek blur.
class LatarSampul extends StatefulWidget {
  final String? url;

  /// Seberapa gelap lapisan penutup (0 = tanpa penutup, 1 = hitam).
  final double kegelapan;

  const LatarSampul({super.key, required this.url, this.kegelapan = 0.35});

  @override
  State<LatarSampul> createState() => _LatarSampulState();
}

class _LatarSampulState extends State<LatarSampul>
    with SingleTickerProviderStateMixin {
  late final AnimationController _putar = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 50),
  );

  /// Hasil kaburan per alamat sampul, agar tidak dihitung ulang ketika
  /// halaman dibuka kembali untuk lagu yang sama.
  static final Map<String, ui.Image> _simpanan = {};

  ui.Image? _gambar;
  String? _urlGambar;

  @override
  void initState() {
    super.initState();
    _sesuaikan();
    latarBergerak.addListener(_sesuaikan);
    _siapkan(widget.url);
  }

  @override
  void didUpdateWidget(covariant LatarSampul lama) {
    super.didUpdateWidget(lama);
    if (lama.url != widget.url) _siapkan(widget.url);
  }

  @override
  void dispose() {
    latarBergerak.removeListener(_sesuaikan);
    _putar.dispose();
    super.dispose();
  }

  void _sesuaikan() {
    if (latarBergerak.value) {
      _putar.repeat();
    } else {
      _putar.stop();
    }
  }

  Future<void> _siapkan(String? url) async {
    if (url == null) return;
    final ada = _simpanan[url];
    if (ada != null) {
      setState(() {
        _gambar = ada;
        _urlGambar = url;
      });
      return;
    }
    try {
      final kecil = await _muatKecil(url);
      final kabur = await _kaburkan(kecil);
      if (_simpanan.length > 30) _simpanan.clear();
      _simpanan[url] = kabur;
      // Lagu sudah berganti lagi selama proses berlangsung.
      if (!mounted || widget.url != url) return;
      setState(() {
        _gambar = kabur;
        _urlGambar = url;
      });
    } catch (_) {
      // Sampul gagal dimuat: latar tetap gelap polos.
    }
  }

  /// Memuat sampul langsung dalam ukuran 24 × 24 piksel.
  static Future<ui.Image> _muatKecil(String url) {
    final selesai = Completer<ui.Image>();
    final aliran = ResizeImage(NetworkImage(url), width: 24, height: 24)
        .resolve(ImageConfiguration.empty);
    late final ImageStreamListener pendengar;
    pendengar = ImageStreamListener(
      (info, _) {
        if (!selesai.isCompleted) selesai.complete(info.image.clone());
        info.dispose();
        aliran.removeListener(pendengar);
      },
      onError: (galat, jejak) {
        if (!selesai.isCompleted) selesai.completeError(galat, jejak);
        aliran.removeListener(pendengar);
      },
    );
    aliran.addListener(pendengar);
    return selesai.future;
  }

  /// Mengaburkan gambar kecil satu kali saja menjadi gambar 128 × 128.
  static Future<ui.Image> _kaburkan(ui.Image kecil) async {
    const ukuran = 128.0;
    final perekam = ui.PictureRecorder();
    Canvas(perekam).drawImageRect(
      kecil,
      Rect.fromLTWH(0, 0, kecil.width.toDouble(), kecil.height.toDouble()),
      const Rect.fromLTWH(0, 0, ukuran, ukuran),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: 14,
          sigmaY: 14,
          tileMode: TileMode.mirror,
        ),
    );
    final hasil =
        await perekam.endRecording().toImage(ukuran.toInt(), ukuran.toInt());
    kecil.dispose();
    return hasil;
  }

  @override
  Widget build(BuildContext context) {
    final gambar = _gambar;

    return IgnorePointer(
      // Gambar diperbesar dan diputar sehingga meluber keluar halaman.
      // ClipRect memotong luberan itu; tanpanya, gambar tetap menutupi
      // halaman lain selama animasi buka/tutup halaman, sehingga terlihat
      // seperti glitch. (Stack tidak memotong hasil Transform.)
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppTheme.latar),
            if (gambar != null)
              // Saat lagu berganti, warna latar berpindah dengan halus.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 900),
                child: RepaintBoundary(
                  key: ValueKey(_urlGambar),
                  child: AnimatedBuilder(
                    animation: _putar,
                    builder: (context, _) {
                      final sudut = _putar.value * 2 * math.pi;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Transform.rotate(
                            angle: sudut,
                            child: Transform.scale(
                              scale: 2.4,
                              child: RawImage(
                                image: gambar,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                          Transform.rotate(
                            angle: -sudut * 0.8 + 1.4,
                            child: Transform.scale(
                              scale: 1.7,
                              alignment: const Alignment(0.4, 0.5),
                              // Transparansi langsung pada gambar lebih ringan
                              // daripada widget Opacity.
                              child: RawImage(
                                image: gambar,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.medium,
                                opacity: const AlwaysStoppedAnimation(0.7),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            // Penutup gelap agar teks putih tetap mudah dibaca.
            ColoredBox(color: Colors.black.withOpacity(widget.kegelapan)),
          ],
        ),
      ),
    );
  }
}
