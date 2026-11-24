import 'package:flutter/material.dart';

import '../models/artis.dart';
import '../models/song.dart';
import '../services/artis_service.dart';
import '../services/player_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';
import '../widgets/state_views.dart';
import 'now_playing_page.dart';

/// Halaman artis bergaya Apple Music: gambar besar dengan nama artis di
/// atasnya, tombol putar, daftar lagu teratas, album, dan keterangan artis.
class ArtisPage extends StatefulWidget {
  /// Lagu yang menjadi titik masuk; dipakai untuk mengetahui sumber data
  /// (iTunes atau Audius) dan id artisnya.
  final Song lagu;

  /// Benar bila halaman dibuka dari halaman pemutar. Saat lagu dipilih,
  /// halaman cukup ditutup agar tumpukan halaman tidak terus bertambah.
  final bool dariPemutar;

  const ArtisPage({super.key, required this.lagu, this.dariPemutar = false});

  @override
  State<ArtisPage> createState() => _ArtisPageState();
}

class _ArtisPageState extends State<ArtisPage> {
  final ArtisService _layanan = ArtisService();
  final ScrollController _gulir = ScrollController();

  late Future<ProfilArtis> _futureProfil;
  bool _judulTampil = false;
  bool _semuaLagu = false;

  static const double _tinggiHeader = 380;

  @override
  void initState() {
    super.initState();
    _futureProfil = _layanan.ambil(widget.lagu);
    // Nama artis di bilah atas baru muncul setelah gambar besar tergulir.
    _gulir.addListener(() {
      final tampil = _gulir.offset > _tinggiHeader - 120;
      if (tampil != _judulTampil) setState(() => _judulTampil = tampil);
    });
  }

  @override
  void dispose() {
    _gulir.dispose();
    super.dispose();
  }

  Future<void> _putar(List<Song> daftar, Song lagu, {bool acak = false}) async {
    if (acak) {
      await pemutarGlobal.putarAcak(daftar);
    } else {
      if (pemutarGlobal.acak) await pemutarGlobal.ubahAcak();
      pemutarGlobal.pilih(lagu, antrean: daftar, langsungPutar: true);
    }
    if (!mounted) return;
    if (widget.dariPemutar) {
      Navigator.pop(context);
    } else {
      NowPlayingPage.buka(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const MiniPlayer(),
      body: Stack(
        children: [
          const AuroraBackground(),
          FutureBuilder<ProfilArtis>(
            future: _futureProfil,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView(pesan: 'Memuat profil artis...');
              }
              if (snapshot.hasError) {
                return SafeArea(
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: BackButton(),
                      ),
                      Expanded(
                        child: ErrorView(
                          pesan: snapshot.error.toString(),
                          onCobaLagi: () => setState(() {
                            _futureProfil = _layanan.ambil(widget.lagu);
                          }),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return _isi(context, snapshot.data!);
            },
          ),
        ],
      ),
    );
  }

  Widget _isi(BuildContext context, ProfilArtis profil) {
    final teks = Theme.of(context).textTheme;
    final lagu = profil.laguTeratas;
    final tampil = _semuaLagu ? lagu : lagu.take(5).toList();

    final lencana = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Lencana(ikon: Icons.music_note_rounded, teks: profil.keterangan),
        if (profil.pengikutSingkat != null)
          _Lencana(
            ikon: Icons.people_alt_rounded,
            teks: '${profil.pengikutSingkat} pengikut',
          ),
        if (profil.lokasi != null)
          _Lencana(ikon: Icons.place_rounded, teks: profil.lokasi!),
        _Lencana(
          ikon: profil.sumber == SumberLagu.audius
              ? Icons.all_inclusive_rounded
              : Icons.timer_outlined,
          teks: profil.sumber == SumberLagu.audius
              ? 'Lagu penuh'
              : 'Pratinjau 30 detik',
        ),
      ],
    );

    // Foto, nama, tombol, dan lencana berada dalam SATU blok. Dulu foto
    // berada di SliverAppBar dan lencana di sliver berikutnya; tinggi
    // keduanya menghasilkan angka pecahan piksel sehingga di sambungannya
    // muncul celah setipis rambut yang terlihat sebagai garis.
    return Stack(
      children: [
        CustomScrollView(
          controller: _gulir,
          slivers: [
            SliverToBoxAdapter(
              child: _BlokAtas(
                profil: profil,
                tinggiFoto: _tinggiHeader + MediaQuery.of(context).padding.top,
                lencana: lencana,
                onPutar: lagu.isEmpty ? null : () => _putar(lagu, lagu.first),
                onAcak: lagu.isEmpty
                    ? null
                    : () => _putar(lagu, lagu.first, acak: true),
              ),
            ),

            // Lagu teratas.
            SliverToBoxAdapter(
              child: _JudulBagian(
                judul: 'Lagu Teratas',
                aksi: lagu.length > 5
                    ? (_semuaLagu ? 'Ringkas' : 'Lihat Semua')
                    : null,
                onAksi: () => setState(() => _semuaLagu = !_semuaLagu),
              ),
            ),
            if (lagu.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Belum ada lagu yang dapat diputar.',
                      style: teks.bodySmall),
                ),
              )
            else
              SliverList.builder(
                itemCount: tampil.length,
                itemBuilder: (context, i) => SongTile(
                  lagu: tampil[i],
                  nomor: i + 1,
                  onTap: () => _putar(lagu, tampil[i]),
                ),
              ),

            // Album (hanya iTunes).
            if (profil.album.isNotEmpty) ...[
              const SliverToBoxAdapter(child: _JudulBagian(judul: 'Album')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: profil.album.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, i) => _KartuAlbum(
                      album: profil.album[i],
                      onTap: () => _bukaAlbum(profil.album[i]),
                    ),
                  ),
                ),
              ),
            ],

            // Tentang artis.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tentang', style: teks.titleLarge),
                    const SizedBox(height: 12),
                    GlassPanel(
                      child: Text(
                        profil.bio ??
                            (profil.sumber == SumberLagu.audius
                                ? '${profil.nama} belum menuliskan bio di Audius.'
                                : '${profil.nama} adalah artis bergenre '
                                    '${profil.keterangan}. Katalog lagu dan album '
                                    'diambil dari iTunes.'),
                        style: teks.bodyMedium?.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Bilah atas melayang: transparan di atas foto, lalu berwarna dan
        // menampilkan nama artis setelah foto tergulir.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AppBar(
            backgroundColor:
                _judulTampil ? AppTheme.latarLembut : Colors.transparent,
            centerTitle: true,
            title: AnimatedOpacity(
              opacity: _judulTampil ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Text(profil.nama, style: teks.titleMedium),
            ),
          ),
        ),
      ],
    );
  }

  /// Lembar berisi daftar lagu dalam satu album.
  void _bukaAlbum(Album album) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.latarLembut,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (konteksLembar) => SizedBox(
        height: MediaQuery.of(konteksLembar).size.height * 0.75,
        child: FutureBuilder<List<Song>>(
          future: _layanan.laguAlbum(album.id),
          builder: (konteksLembar, snapshot) {
            final teks = Theme.of(konteksLembar).textTheme;
            final daftar = snapshot.data ?? const <Song>[];

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: album.sampul == null
                              ? const ColoredBox(color: Color(0xFF1C1C22))
                              : Image.network(album.sampul!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(album.nama,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: teks.titleMedium),
                            const SizedBox(height: 4),
                            Text('${album.tahun} · ${album.jumlahLagu} lagu',
                                style: teks.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : snapshot.hasError
                          ? Center(child: Text(snapshot.error.toString()))
                          : ListView.builder(
                              itemCount: daftar.length,
                              itemBuilder: (_, i) => SongTile(
                                lagu: daftar[i],
                                nomor: i + 1,
                                onTap: () {
                                  Navigator.pop(konteksLembar);
                                  _putar(daftar, daftar[i]);
                                },
                              ),
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Bagian atas halaman: foto besar, gradasi gelap, nama artis, tombol putar
/// dan acak, serta lencana keterangan, digambar sebagai satu blok utuh.
class _BlokAtas extends StatelessWidget {
  final ProfilArtis profil;
  final double tinggiFoto;
  final Widget lencana;
  final VoidCallback? onPutar;
  final VoidCallback? onAcak;

  const _BlokAtas({
    required this.profil,
    required this.tinggiFoto,
    required this.lencana,
    this.onPutar,
    this.onAcak,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: tinggiFoto,
          child: profil.gambar == null
              ? const ColoredBox(color: AppTheme.latarLembut)
              : Image.network(
                  profil.gambar!,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.3),
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: AppTheme.latarLembut),
                ),
        ),
        // Gradasi agar nama artis terbaca; ujung bawahnya warna latar pekat.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: tinggiFoto,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.4, 0.8, 1],
                colors: [
                  const Color(0x66000000),
                  Colors.transparent,
                  AppTheme.latar.withOpacity(0.85),
                  AppTheme.latar,
                ],
              ),
            ),
          ),
        ),
        // Lanjutan gradasi di bawah foto. Sengaja tumpang tindih 2 piksel
        // dengan ujung foto agar tidak ada celah di antara keduanya.
        Positioned(
          top: tinggiFoto - 2,
          left: 0,
          right: 0,
          height: 50,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.latar, Color(0x0007070A)],
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: tinggiFoto,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          profil.nama,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 36,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: 'Acak',
                        onPressed: onAcak,
                        icon: const Icon(Icons.shuffle_rounded),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        tooltip: 'Putar',
                        iconSize: 32,
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.aksen,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: onPutar,
                        icon: const Icon(Icons.play_arrow_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: lencana,
            ),
          ],
        ),
      ],
    );
  }
}

class _JudulBagian extends StatelessWidget {
  final String judul;
  final String? aksi;
  final VoidCallback? onAksi;

  const _JudulBagian({required this.judul, this.aksi, this.onAksi});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(judul, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (aksi != null)
            TextButton(
              onPressed: onAksi,
              child: Text(aksi!, style: const TextStyle(color: AppTheme.aksen)),
            ),
        ],
      ),
    );
  }
}

class _Lencana extends StatelessWidget {
  final IconData ikon;
  final String teks;

  const _Lencana({required this.ikon, required this.teks});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.kacaTepi),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: Colors.white60),
          const SizedBox(width: 6),
          Text(teks, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Kartu album: sampul, nama, dan tahun rilis.
class _KartuAlbum extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;

  const _KartuAlbum({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    const ukuran = 150.0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: ukuran,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: ukuran,
                height: ukuran,
                child: album.sampul == null
                    ? const ColoredBox(color: Color(0xFF1C1C22))
                    : Image.network(album.sampul!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            Text(album.nama,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: teks.titleMedium),
            Text(album.tahun, style: teks.bodySmall),
          ],
        ),
      ),
    );
  }
}
