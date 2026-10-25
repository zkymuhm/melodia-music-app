import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/favorite_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/song_tile.dart';
import 'detail_page.dart';

/// Halaman akun. Proses masuk (login) belum tersedia, sehingga halaman ini
/// menampilkan profil tamu beserta data favorit yang tersimpan di perangkat.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final FavoriteService _layanan = FavoriteService();
  late Future<List<Song>> _futureFavorit;

  @override
  void initState() {
    super.initState();
    _futureFavorit = _layanan.ambilSemua();

    // Halaman ini berada di dalam IndexedStack sehingga tidak dibangun ulang
    // saat tab berpindah. Perubahan favorit dari halaman lain dipantau lewat
    // penanda versi agar ringkasan di sini selalu mutakhir.
    versiFavorit.addListener(_muatUlang);
  }

  @override
  void dispose() {
    versiFavorit.removeListener(_muatUlang);
    super.dispose();
  }

  void _muatUlang() {
    if (!mounted) return;
    setState(() => _futureFavorit = _layanan.ambilSemua());
  }

  void _belumTersedia(String fitur) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        content: Text('$fitur belum tersedia pada versi ini.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
        children: [
          Text('Akun', style: teks.headlineLarge),
          const SizedBox(height: 18),

          // Kartu profil
          GlassPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppTheme.aksen, Color(0xFF7B2FF7)],
                    ),
                  ),
                  child: const Icon(Icons.person_rounded,
                      size: 42, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text('Pengguna Tamu', style: teks.titleLarge),
                const SizedBox(height: 4),
                Text('Masuk untuk menyimpan pustaka di cloud',
                    textAlign: TextAlign.center, style: teks.bodySmall),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _belumTersedia('Fitur masuk'),
                    child: const Text('Masuk'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Ringkasan jumlah lagu favorit
          FutureBuilder<List<Song>>(
            future: _futureFavorit,
            builder: (context, snapshot) {
              final favorit = snapshot.data ?? const <Song>[];
              final memuat =
                  snapshot.connectionState == ConnectionState.waiting;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _KartuAngka(
                          label: 'Lagu Favorit',
                          nilai: memuat ? '—' : '${favorit.length}',
                          ikon: Icons.favorite_rounded,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _KartuAngka(
                          label: 'Artis Berbeda',
                          nilai: memuat
                              ? '—'
                              : '${favorit.map((l) => l.artistName).toSet().length}',
                          ikon: Icons.mic_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text('Pustaka Favorit', style: teks.titleLarge),
                  const SizedBox(height: 12),
                  if (memuat)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (favorit.isEmpty)
                    GlassPanel(
                      child: Row(
                        children: [
                          const Icon(Icons.favorite_border_rounded,
                              color: Colors.white54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Belum ada lagu favorit. Tandai lagu lewat '
                              'ikon hati di halaman detail.',
                              style: teks.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: favorit
                            .take(5)
                            .map((lagu) => SongTile(
                                  lagu: lagu,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DetailPage(lagu: lagu),
                                      ),
                                    );
                                    _muatUlang();
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 26),

          Text('Pengaturan', style: teks.titleLarge),
          const SizedBox(height: 12),
          GlassPanel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _BarisMenu(
                  ikon: Icons.notifications_rounded,
                  judul: 'Notifikasi',
                  onTap: () => _belumTersedia('Pengaturan notifikasi'),
                ),
                _BarisMenu(
                  ikon: Icons.high_quality_rounded,
                  judul: 'Kualitas Audio',
                  onTap: () => _belumTersedia('Pengaturan kualitas audio'),
                ),
                _BarisMenu(
                  ikon: Icons.info_rounded,
                  judul: 'Tentang Aplikasi',
                  keterangan: 'Versi 1.0.0',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Melodia',
                    applicationVersion: '1.0.0',
                    children: const [
                      Text(
                        'Aplikasi penjelajah musik yang menyajikan data dari '
                        'iTunes Search API dan lirik dari lyrics.ovh.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu kecil berisi satu angka ringkasan.
class _KartuAngka extends StatelessWidget {
  final String label;
  final String nilai;
  final IconData ikon;

  const _KartuAngka({
    required this.label,
    required this.nilai,
    required this.ikon,
  });

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: AppTheme.aksen, size: 20),
          const SizedBox(height: 10),
          Text(nilai,
              style: teks.headlineLarge?.copyWith(fontSize: 26)),
          const SizedBox(height: 2),
          Text(label, style: teks.bodySmall),
        ],
      ),
    );
  }
}

/// Satu baris menu pengaturan.
class _BarisMenu extends StatelessWidget {
  final IconData ikon;
  final String judul;
  final String? keterangan;
  final VoidCallback onTap;

  const _BarisMenu({
    required this.ikon,
    required this.judul,
    required this.onTap,
    this.keterangan,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(ikon, color: Colors.white70, size: 21),
      title: Text(judul, style: Theme.of(context).textTheme.titleMedium),
      subtitle: keterangan == null ? null : Text(keterangan!),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
    );
  }
}
