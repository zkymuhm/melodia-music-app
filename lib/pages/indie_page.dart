import 'dart:async';

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/audius_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/song_tile.dart';
import '../widgets/state_views.dart';
import 'now_playing_page.dart';

/// Halaman musik independen dari Audius.
///
/// Berbeda dengan katalog iTunes yang hanya menyediakan pratinjau, seluruh
/// lagu pada halaman ini dapat diputar secara utuh tanpa langganan.
/// Pengguna dapat menyaring lagu berdasarkan genre dan rentang waktu
/// popularitas agar hasilnya lebih sesuai selera.
class IndiePage extends StatefulWidget {
  const IndiePage({super.key});

  @override
  State<IndiePage> createState() => _IndiePageState();
}

class _IndiePageState extends State<IndiePage> {
  final AudiusApiService _api = AudiusApiService();
  final TextEditingController _kolom = TextEditingController();

  Timer? _penunda;
  late Future<List<Song>> _futureLagu;
  String _kataKunci = '';

  /// Genre terpilih. Null berarti semua genre.
  String? _genre;

  /// Rentang waktu popularitas. Bawaannya "Sepanjang Masa" karena berisi
  /// lagu yang sudah didengar banyak orang, bukan sekadar lagu baru.
  String _periode = 'allTime';

  @override
  void initState() {
    super.initState();
    _futureLagu = _ambil();
  }

  @override
  void dispose() {
    _penunda?.cancel();
    _kolom.dispose();
    super.dispose();
  }

  /// Menentukan permintaan yang dikirim sesuai kondisi saat ini:
  /// mode pencarian atau mode lagu populer.
  Future<List<Song>> _ambil() {
    if (_kataKunci.isEmpty) {
      return _api.laguPopuler(genre: _genre, periode: _periode);
    }
    return _api.cariLagu(_kataKunci, genre: _genre);
  }

  // Badan setState harus berupa blok { }. Bentuk panah `() => _future = ...`
  // mengembalikan Future sehingga setState ditolak Flutter dan layar tidak
  // diperbarui.
  void _muatUlang() {
    setState(() {
      _futureLagu = _ambil();
    });
  }

  void _cari(String kataKunci) {
    _kataKunci = kataKunci;
    _muatUlang();
  }

  void _pilihGenre(String? genre) {
    if (genre == _genre) return;
    _genre = genre;
    _muatUlang();
  }

  void _pilihPeriode(String periode) {
    if (periode == _periode) return;
    _periode = periode;
    _muatUlang();
  }

  /// Menunda permintaan 600 ms setelah ketikan terakhir agar aplikasi tidak
  /// memanggil API pada setiap huruf yang diketik.
  void _saatMengetik(String nilai) {
    _penunda?.cancel();
    _penunda = Timer(const Duration(milliseconds: 600), () {
      final bersih = nilai.trim();
      if (bersih != _kataKunci) _cari(bersih);
    });
  }

  String get _judulDaftar {
    final genre = _genre == null ? '' : ' · $_genre';
    if (_kataKunci.isNotEmpty) return 'Hasil untuk "$_kataKunci"$genre';
    return 'Populer ${AudiusApiService.daftarPeriode[_periode]}$genre';
  }

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Musik Indie', style: teks.headlineLarge),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.all_inclusive_rounded,
                        size: 15, color: AppTheme.aksen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Karya musisi independen, dapat diputar penuh '
                        'tanpa langganan.',
                        style: teks.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              radius: BorderRadius.circular(14),
              child: TextField(
                controller: _kolom,
                onChanged: _saatMengetik,
                textInputAction: TextInputAction.search,
                onSubmitted: (nilai) => _cari(nilai.trim()),
                style: teks.bodyMedium?.copyWith(color: Colors.white),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  icon: Icon(Icons.search_rounded, color: Colors.white60),
                  hintText: 'Cari lagu atau musisi indie',
                ),
              ),
            ),
          ),

          // Baris filter genre.
          _BarisPilihan(
            pilihan: [
              (nilai: null, label: 'Semua'),
              ...AudiusApiService.daftarGenre.map((g) => (nilai: g, label: g)),
            ],
            terpilih: _genre,
            onPilih: _pilihGenre,
          ),

          // Baris periode hanya relevan untuk daftar populer.
          if (_kataKunci.isEmpty) ...[
            const SizedBox(height: 8),
            _BarisPilihan(
              pilihan: AudiusApiService.daftarPeriode.entries
                  .map((e) => (nilai: e.key, label: e.value))
                  .toList(),
              terpilih: _periode,
              onPilih: (nilai) => _pilihPeriode(nilai ?? 'allTime'),
              kecil: true,
            ),
          ],
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _judulDaftar,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: teks.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Song>>(
              future: _futureLagu,
              builder: (context, snapshot) {
                // Kondisi 1: menunggu respons dari server.
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView(pesan: 'Memuat musik indie...');
                }

                // Kondisi 2: permintaan gagal.
                if (snapshot.hasError) {
                  return ErrorView(
                    pesan: snapshot.error.toString(),
                    onCobaLagi: _muatUlang,
                  );
                }

                // Kondisi 3: data berhasil diperoleh.
                final daftar = snapshot.data ?? const <Song>[];
                if (daftar.isEmpty) {
                  return EmptyView(
                    pesan: _kataKunci.isEmpty
                        ? 'Belum ada lagu untuk filter ini.'
                        : 'Tidak ada lagu indie yang cocok dengan '
                            '"$_kataKunci"${_genre == null ? '' : ' pada genre $_genre'}.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _muatUlang(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: daftar.length,
                    itemBuilder: (context, index) => SongTile(
                      lagu: daftar[index],
                      nomor: index + 1,
                      onTap: () => NowPlayingPage.putar(
                        context,
                        daftar[index],
                        antrean: daftar,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Deretan pilihan berbentuk pil yang dapat digeser mendatar.
class _BarisPilihan extends StatelessWidget {
  final List<({String? nilai, String label})> pilihan;
  final String? terpilih;
  final ValueChanged<String?> onPilih;
  final bool kecil;

  const _BarisPilihan({
    required this.pilihan,
    required this.terpilih,
    required this.onPilih,
    this.kecil = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kecil ? 30 : 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: pilihan.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = pilihan[i];
          final aktif = item.nilai == terpilih;
          return GestureDetector(
            onTap: () => onPilih(item.nilai),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: kecil ? 12 : 16),
              decoration: BoxDecoration(
                color: aktif
                    ? (kecil ? Colors.white : AppTheme.aksen)
                    : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: aktif ? Colors.transparent : AppTheme.kacaTepi,
                ),
              ),
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: kecil ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: aktif
                      ? (kecil ? Colors.black : Colors.white)
                      : Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
