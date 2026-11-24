import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/favorite_service.dart';
import '../services/player_controller.dart';
import '../services/playlist_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/mini_player.dart';
import '../widgets/playlist_sheet.dart';
import '../widgets/song_tile.dart';
import 'now_playing_page.dart';

/// Isi satu playlist.
///
/// Bila [idPlaylist] bernilai null, halaman ini menampilkan koleksi
/// "Lagu Favorit" dengan tampilan yang sama.
class PlaylistDetailPage extends StatefulWidget {
  final String? idPlaylist;

  const PlaylistDetailPage({super.key, this.idPlaylist});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

/// Data yang ditampilkan: nama koleksi dan daftar lagunya.
typedef _Koleksi = ({String nama, List<Song> lagu});

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  final PlaylistService _layanan = PlaylistService();
  final FavoriteService _layananFavorit = FavoriteService();

  late Future<_Koleksi?> _futureKoleksi;

  /// Lagu yang baru digeser untuk dihapus. Disembunyikan seketika karena
  /// Dismissible tidak boleh tetap tampil sementara data dimuat ulang.
  final Set<String> _dihapus = {};

  bool get _modeFavorit => widget.idPlaylist == null;

  @override
  void initState() {
    super.initState();
    _futureKoleksi = _muat();
    versiPlaylist.addListener(_muatUlang);
    versiFavorit.addListener(_muatUlang);
  }

  @override
  void dispose() {
    versiPlaylist.removeListener(_muatUlang);
    versiFavorit.removeListener(_muatUlang);
    super.dispose();
  }

  Future<_Koleksi?> _muat() async {
    if (_modeFavorit) {
      return (nama: 'Lagu Favorit', lagu: await _layananFavorit.ambilSemua());
    }
    final p = await _layanan.ambil(widget.idPlaylist!);
    if (p == null) return null;
    return (nama: p.nama, lagu: p.lagu);
  }

  void _muatUlang() {
    if (!mounted) return;
    setState(() {
      _futureKoleksi = _muat();
    });
  }

  Future<void> _hapusLagu(Song lagu) async {
    if (_modeFavorit) {
      await _layananFavorit.ubahStatus(lagu);
    } else {
      await _layanan.hapusLagu(widget.idPlaylist!, lagu.id);
    }
  }

  Future<void> _ubahNama(String namaLama) async {
    final nama = await mintaNamaPlaylist(
      context,
      awal: namaLama,
      judul: 'Ubah Nama',
    );
    if (nama == null) return;
    await _layanan.ubahNama(widget.idPlaylist!, nama);
  }

  Future<void> _hapusPlaylist(String nama) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.latarLembut,
        title: const Text('Hapus playlist?'),
        content: Text('"$nama" akan dihapus. Lagu di dalamnya tidak ikut '
            'terhapus dari favorit.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    await _layanan.hapus(widget.idPlaylist!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _putar(List<Song> daftar, {Song? mulai}) async {
    // Mode acak dimatikan agar urutan mengikuti playlist.
    if (pemutarGlobal.acak) await pemutarGlobal.ubahAcak();
    await pemutarGlobal.pilih(
      mulai ?? daftar.first,
      antrean: daftar,
      langsungPutar: true,
    );
    if (mounted) NowPlayingPage.buka(context);
  }

  Future<void> _putarAcak(List<Song> daftar) async {
    await pemutarGlobal.putarAcak(daftar);
    if (mounted) NowPlayingPage.buka(context);
  }

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return FutureBuilder<_Koleksi?>(
      future: _futureKoleksi,
      builder: (context, snapshot) {
        final koleksi = snapshot.data;
        final daftar = (koleksi?.lagu ?? const <Song>[])
            .where((l) => !_dihapus.contains(l.id))
            .toList();
        final nama = koleksi?.nama ?? '';

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            actions: [
              if (!_modeFavorit && koleksi != null)
                PopupMenuButton<String>(
                  onSelected: (aksi) =>
                      aksi == 'ubah' ? _ubahNama(nama) : _hapusPlaylist(nama),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'ubah', child: Text('Ubah nama')),
                    PopupMenuItem(
                        value: 'hapus', child: Text('Hapus playlist')),
                  ],
                ),
            ],
          ),
          bottomNavigationBar: const MiniPlayer(),
          body: Stack(
            children: [
              const AuroraBackground(),
              SafeArea(
                child: _isi(context, snapshot, koleksi, daftar, nama, teks),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _isi(
    BuildContext context,
    AsyncSnapshot<_Koleksi?> snapshot,
    _Koleksi? koleksi,
    List<Song> daftar,
    String nama,
    TextTheme teks,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (koleksi == null) {
      return const Center(child: Text('Playlist tidak ditemukan.'));
    }

    final totalDetik = daftar.fold<int>(0, (j, l) => j + l.durasiDetik);
    final sampul = daftar.isEmpty ? null : daftar.first.artworkBesar;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 48, 0, 24),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 170,
              height: 170,
              child: sampul == null
                  ? Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.aksen, Color(0xFF7B2FF7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        _modeFavorit
                            ? Icons.favorite_rounded
                            : Icons.queue_music_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    )
                  : Image.network(sampul, fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(nama,
              textAlign: TextAlign.center, style: teks.headlineLarge),
        ),
        const SizedBox(height: 4),
        Text(
          '${daftar.length} lagu · ${totalDetik ~/ 60} menit',
          textAlign: TextAlign.center,
          style: teks.bodySmall,
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: daftar.isEmpty ? null : () => _putar(daftar),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Putar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: daftar.isEmpty ? null : () => _putarAcak(daftar),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Acak'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (daftar.isEmpty)
          Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              _modeFavorit
                  ? 'Belum ada lagu favorit. Tandai lagu lewat ikon hati.'
                  : 'Playlist masih kosong. Tambahkan lagu lewat ikon '
                      'playlist di halaman pemutar.',
              textAlign: TextAlign.center,
              style: teks.bodySmall,
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text('Geser lagu ke kiri untuk menghapus.',
                style: teks.bodySmall),
          ),
          ...List.generate(daftar.length, (i) {
            final lagu = daftar[i];
            return Dismissible(
              key: ValueKey(lagu.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                color: AppTheme.aksen.withOpacity(0.8),
                child: const Icon(Icons.delete_outline_rounded),
              ),
              onDismissed: (_) {
                setState(() => _dihapus.add(lagu.id));
                _hapusLagu(lagu);
              },
              child: SongTile(
                lagu: lagu,
                nomor: i + 1,
                onTap: () => _putar(daftar, mulai: lagu),
              ),
            );
          }),
        ],
      ],
    );
  }
}
