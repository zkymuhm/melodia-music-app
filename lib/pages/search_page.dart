import 'dart:async';

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/music_api_service.dart';
import '../widgets/glass.dart';
import '../widgets/song_tile.dart';
import '../widgets/state_views.dart';
import 'detail_page.dart';

/// Halaman pencarian lagu berdasarkan judul, artis, atau album.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final MusicApiService _api = MusicApiService();
  final TextEditingController _kolom = TextEditingController();

  static const List<String> _saran = [
    'Tulus',
    'Hindia',
    'Nadin Amizah',
    'Pamungkas',
    'Feast',
    'Raisa',
  ];

  Timer? _penunda;
  Future<List<Song>>? _futureHasil;
  String _kataKunci = '';

  @override
  void dispose() {
    _penunda?.cancel();
    _kolom.dispose();
    super.dispose();
  }

  void _cari(String kataKunci) {
    setState(() {
      _kataKunci = kataKunci;
      _futureHasil = _api.cariLagu(kataKunci);
    });
  }

  /// Menunda permintaan 600 ms setelah ketikan terakhir agar aplikasi tidak
  /// memanggil API pada setiap huruf yang diketik.
  void _saatMengetik(String nilai) {
    _penunda?.cancel();
    _penunda = Timer(const Duration(milliseconds: 600), () {
      final bersih = nilai.trim();
      if (bersih.isEmpty) {
        setState(() {
          _kataKunci = '';
          _futureHasil = null;
        });
      } else if (bersih != _kataKunci) {
        _cari(bersih);
      }
    });
  }

  void _pilihSaran(String nama) {
    _kolom.text = nama;
    _cari(nama);
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Cari', style: teks.headlineLarge),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
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
                  hintText: 'Lagu, artis, atau album',
                ),
              ),
            ),
          ),
          Expanded(child: _isi()),
        ],
      ),
    );
  }

  Widget _isi() {
    // Belum ada kata kunci: tampilkan saran pencarian.
    if (_futureHasil == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Telusuri Artis',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _saran
                  .map((nama) => GlassPanel(
                        onTap: () => _pilihSaran(nama),
                        radius: BorderRadius.circular(30),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        child: Text(nama,
                            style: Theme.of(context).textTheme.titleMedium),
                      ))
                  .toList(),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<Song>>(
      future: _futureHasil,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(pesan: 'Mencari lagu...');
        }
        if (snapshot.hasError) {
          return ErrorView(
            pesan: snapshot.error.toString(),
            onCobaLagi: () => _cari(_kataKunci),
          );
        }

        final hasil = snapshot.data ?? const <Song>[];
        if (hasil.isEmpty) {
          return EmptyView(
            pesan: 'Tidak ada lagu yang cocok dengan "$_kataKunci".',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: hasil.length,
          itemBuilder: (context, index) => SongTile(
            lagu: hasil[index],
            nomor: index + 1,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailPage(lagu: hasil[index]),
              ),
            ),
          ),
        );
      },
    );
  }
}
