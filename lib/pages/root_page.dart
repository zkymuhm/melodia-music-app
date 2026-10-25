import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/mini_player.dart';
import 'account_page.dart';
import 'dashboard_page.dart';
import 'indie_page.dart';
import 'search_page.dart';

/// Kerangka utama aplikasi: latar aurora, isi halaman, dan bilah navigasi
/// kaca yang melayang di atas konten.
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _indeks = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody membuat isi halaman tetap terlihat di balik bilah navigasi,
      // sehingga efek kaca pada bilah benar-benar tampak.
      extendBody: true,
      body: Stack(
        children: [
          const AuroraBackground(),
          IndexedStack(
            index: _indeks,
            children: const [
              DashboardPage(),
              IndiePage(),
              SearchPage(),
              AccountPage(),
            ],
          ),
        ],
      ),
      // Bar pemutar dan bilah navigasi ditumpuk rata di bagian bawah layar.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          _BilahKaca(
            indeks: _indeks,
            onPilih: (nilai) => setState(() => _indeks = nilai),
          ),
        ],
      ),
    );
  }
}

class _BilahKaca extends StatelessWidget {
  final int indeks;
  final ValueChanged<int> onPilih;

  const _BilahKaca({required this.indeks, required this.onPilih});

  static const _menu = [
    (ikon: Icons.play_circle_fill_rounded, label: 'Dashboard'),
    (ikon: Icons.all_inclusive_rounded, label: 'Indie'),
    (ikon: Icons.search_rounded, label: 'Cari'),
    (ikon: Icons.person_rounded, label: 'Akun'),
  ];

  @override
  Widget build(BuildContext context) {
    // ClipRect membatasi area blur hanya pada bilah ini. Tanpa clip,
    // BackdropFilter akan mengaburkan seluruh isi layar di belakangnya.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            border: Border(top: BorderSide(color: AppTheme.kacaTepi)),
          ),
          padding: EdgeInsets.only(
            top: 10,
            bottom: 10 + MediaQuery.of(context).padding.bottom,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_menu.length, (i) {
              final aktif = i == indeks;
              final warna = aktif ? AppTheme.aksen : Colors.white60;
              return Expanded(
                child: InkWell(
                  onTap: () => onPilih(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_menu[i].ikon, color: warna, size: 25),
                      const SizedBox(height: 3),
                      Text(
                        _menu[i].label,
                        style: TextStyle(
                          color: warna,
                          fontSize: 11,
                          fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
