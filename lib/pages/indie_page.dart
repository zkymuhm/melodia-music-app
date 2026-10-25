import 'dart:async';

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/audius_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/song_tile.dart';
import '../widgets/state_views.dart';
import 'detail_page.dart';

/// Halaman musik independen dari Audius.
///
/// Berbeda dengan katalog iTunes yang hanya menyediakan pratinjau, seluruh
/// lagu pada halaman ini dapat diputar secara utuh tanpa langganan.
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

  @override
  void initState() {
    super.initState();
    _futureLagu = _api.laguPopuler();
  }

  @override
  void dispose() {
    _penunda?.cancel();
    _kolom.dispose();
    super.dispose();
  }

  void _muatPopuler() {
    setState(() {
      _kataKunci = '';
      _futureLagu = _api.laguPopuler();
    });
  }

  void _cari(String kataKunci) {
    setState(() {
      _kataKunci = kataKunci;
      _futureLagu = _api.cariLagu(kataKunci);
    });
  }

  /// Menunda permintaan 600 ms setelah ketikan terakhir agar aplikasi tidak
  /// memanggil API pada setiap huruf yang diketik.
  void _saatMengetik(String nilai) {
    _penunda?.cancel();
    _penunda = Timer(const Duration(milliseconds: 600), () {
      final bersih = nilai.trim();
      if (bersih.isEmpty) {
        _muatPopuler();
      } else if (bersih != _kataKunci) {
        _cari(bersih);
      }
    });
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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              radius: BorderRadius.circular(14),
              child: TextField(
                controller: _kolom,
                onChanged: _saatMengetik,
                textInputAction: TextInputAction.search,
                onSubmitted: (nilai) {
                  final bersih = nilai.trim();
                  if (bersih.isNotEmpty) _cari(bersih);
                },
                style: teks.bodyMedium?.copyWith(color: Colors.white),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  icon: Icon(Icons.search_rounded, color: Colors.white60),
                  hintText: 'Cari lagu atau musisi indie',
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _kataKunci.isEmpty
                    ? 'Sedang Populer di Audius'
                    : 'Hasil untuk "$_kataKunci"',
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
                    onCobaLagi: () => _kataKunci.isEmpty
                        ? _muatPopuler()
                        : _cari(_kataKunci),
                  );
                }

                // Kondisi 3: data berhasil diperoleh.
                final daftar = snapshot.data ?? const <Song>[];
                if (daftar.isEmpty) {
                  return EmptyView(
                    pesan: _kataKunci.isEmpty
                        ? 'Belum ada lagu yang dapat ditampilkan.'
                        : 'Tidak ada lagu indie yang cocok dengan '
                            '"$_kataKunci".',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      _kataKunci.isEmpty ? _muatPopuler() : _cari(_kataKunci),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: daftar.length,
                    itemBuilder: (context, index) => SongTile(
                      lagu: daftar[index],
                      nomor: index + 1,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailPage(lagu: daftar[index]),
                        ),
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
