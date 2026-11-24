import 'package:flutter/material.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../services/favorite_service.dart';
import '../services/playlist_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/playlist_sheet.dart';
import 'playlist_detail_page.dart';

/// Halaman daftar playlist (tab "Playlist").
///
/// Menampilkan koleksi "Lagu Favorit" di urutan teratas, diikuti playlist
/// buatan pengguna. Seluruh data tersimpan di perangkat.
class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final PlaylistService _layanan = PlaylistService();
  final FavoriteService _layananFavorit = FavoriteService();

  late Future<(List<Playlist>, List<Song>)> _futureData;

  @override
  void initState() {
    super.initState();
    _futureData = _muat();
    // Halaman berada di IndexedStack, jadi perubahan dari halaman lain
    // dipantau lewat penanda versi.
    versiPlaylist.addListener(_muatUlang);
    versiFavorit.addListener(_muatUlang);
  }

  @override
  void dispose() {
    versiPlaylist.removeListener(_muatUlang);
    versiFavorit.removeListener(_muatUlang);
    super.dispose();
  }

  /// Playlist dan favorit diambil bersamaan.
  Future<(List<Playlist>, List<Song>)> _muat() async {
    final hasil = await Future.wait([
      _layanan.ambilSemua(),
      _layananFavorit.ambilSemua(),
    ]);
    return (hasil[0] as List<Playlist>, hasil[1] as List<Song>);
  }

  void _muatUlang() {
    if (!mounted) return;
    setState(() {
      _futureData = _muat();
    });
  }

  Future<void> _buatBaru() async {
    final nama = await mintaNamaPlaylist(context);
    if (nama == null) return;
    await _layanan.buat(nama);
  }

  void _buka({String? idPlaylist}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailPage(idPlaylist: idPlaylist),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: FutureBuilder<(List<Playlist>, List<Song>)>(
        future: _futureData,
        builder: (context, snapshot) {
          final playlist = snapshot.data?.$1 ?? const <Playlist>[];
          final favorit = snapshot.data?.$2 ?? const <Song>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Playlist', style: teks.headlineLarge),
                  ),
                  IconButton.filled(
                    tooltip: 'Buat playlist',
                    onPressed: _buatBaru,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _KartuPlaylist(
                judul: 'Lagu Favorit',
                keterangan: '${favorit.length} lagu',
                sampul: null,
                ikon: Icons.favorite_rounded,
                onTap: () => _buka(),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (playlist.isEmpty)
                GlassPanel(
                  child: Row(
                    children: [
                      const Icon(Icons.queue_music_rounded,
                          color: Colors.white54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Belum ada playlist. Tekan tombol + untuk membuat, '
                          'atau tambahkan lagu dari halaman pemutar.',
                          style: teks.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...playlist.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _KartuPlaylist(
                      judul: p.nama,
                      keterangan: '${p.lagu.length} lagu · ${p.totalDurasi}',
                      sampul: p.sampul,
                      ikon: Icons.queue_music_rounded,
                      onTap: () => _buka(idPlaylist: p.id),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _KartuPlaylist extends StatelessWidget {
  final String judul;
  final String keterangan;
  final String? sampul;
  final IconData ikon;
  final VoidCallback onTap;

  const _KartuPlaylist({
    required this.judul,
    required this.keterangan,
    required this.sampul,
    required this.ikon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final kotakIkon = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.aksen, Color(0xFF7B2FF7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(ikon, color: Colors.white, size: 30),
    );

    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: sampul == null
                  ? kotakIkon
                  : Image.network(
                      sampul!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => kotakIkon,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: teks.titleMedium?.copyWith(fontSize: 16)),
                const SizedBox(height: 3),
                Text(keterangan, style: teks.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white38),
        ],
      ),
    );
  }
}
