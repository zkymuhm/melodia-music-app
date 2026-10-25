import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/music_api_service.dart';
import '../widgets/album_card.dart';
import '../widgets/glass.dart';
import '../widgets/state_views.dart';
import 'detail_page.dart';

/// Halaman dashboard: kumpulan baris rekomendasi mendatar yang seluruh
/// datanya diambil dari API.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final MusicApiService _api = MusicApiService();

  /// Pemetaan judul baris pada tampilan ke kata kunci yang dikirim ke API.
  static const Map<String, String> _kategori = {
    'Sedang Populer': 'lagu indonesia',
    'Pop Indonesia': 'pop indonesia',
    'Rock & Alternatif': 'rock indonesia',
    'Suasana Santai': 'akustik indonesia',
  };

  late Future<Map<String, List<Song>>> _futureBeranda;

  @override
  void initState() {
    super.initState();
    _futureBeranda = _api.ambilBeranda(_kategori.values.toList());
  }

  void _muatUlang() {
    setState(() {
      _futureBeranda = _api.ambilBeranda(_kategori.values.toList());
    });
  }

  /// Menyaring agar satu baris tidak menampilkan beberapa lagu dari album
  /// yang sama, sehingga sampul pada daftar mendatar tampak beragam.
  List<Song> _ragam(List<Song> daftar) {
    final album = <String>{};
    final hasil = <Song>[];
    for (final lagu in daftar) {
      if (album.add(lagu.collectionName)) hasil.add(lagu);
    }
    return hasil;
  }

  void _bukaDetail(Song lagu) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailPage(lagu: lagu)),
    );
  }

  String get _sapaan {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat pagi';
    if (jam < 15) return 'Selamat siang';
    if (jam < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: FutureBuilder<Map<String, List<Song>>>(
        future: _futureBeranda,
        builder: (context, snapshot) {
          // Kondisi 1: menunggu respons dari server.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }

          // Kondisi 2: permintaan gagal.
          if (snapshot.hasError) {
            return ErrorView(
              pesan: snapshot.error.toString(),
              onCobaLagi: _muatUlang,
            );
          }

          // Kondisi 3: data berhasil diperoleh.
          final data = snapshot.data ?? {};
          final sorotan = data.values
              .firstWhere((daftar) => daftar.isNotEmpty, orElse: () => [])
              .cast<Song>();

          return RefreshIndicator(
            onRefresh: () async => _muatUlang(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_sapaan, style: teks.bodyMedium),
                      const SizedBox(height: 2),
                      Text('Dengarkan Sekarang',
                          style: teks.headlineLarge),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (sorotan.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _KartuSorotan(
                      lagu: sorotan.first,
                      onTap: () => _bukaDetail(sorotan.first),
                    ),
                  ),
                const SizedBox(height: 26),
                ..._kategori.entries.map((entri) {
                  final daftar = data[entri.value] ?? const <Song>[];
                  if (daftar.isEmpty) return const SizedBox.shrink();
                  return _BarisKategori(
                    judul: entri.key,
                    daftar: _ragam(daftar).take(12).toList(),
                    onPilih: _bukaDetail,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Kartu besar di bagian atas dashboard untuk satu lagu pilihan.
class _KartuSorotan extends StatelessWidget {
  final Song lagu;
  final VoidCallback onTap;

  const _KartuSorotan({required this.lagu, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 92,
              height: 92,
              child: lagu.artworkBesar == null
                  ? const ColoredBox(color: Color(0xFF1C1C22))
                  : Image.network(lagu.artworkBesar!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PILIHAN HARI INI',
                    style: teks.bodySmall?.copyWith(letterSpacing: 1.4)),
                const SizedBox(height: 6),
                Text(
                  lagu.trackName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: teks.titleLarge,
                ),
                Text(
                  lagu.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: teks.bodyMedium,
                ),
              ],
            ),
          ),
          const Icon(Icons.play_circle_fill_rounded, size: 40),
        ],
      ),
    );
  }
}

/// Satu baris kategori berisi daftar kartu album yang dapat digeser mendatar.
class _BarisKategori extends StatelessWidget {
  final String judul;
  final List<Song> daftar;
  final ValueChanged<Song> onPilih;

  const _BarisKategori({
    required this.judul,
    required this.daftar,
    required this.onPilih,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(judul, style: Theme.of(context).textTheme.titleLarge),
        ),
        SizedBox(
          height: 188,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: daftar.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => AlbumCard(
              lagu: daftar[index],
              onTap: () => onPilih(daftar[index]),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
