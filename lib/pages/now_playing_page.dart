import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import '../services/favorite_service.dart';
import '../services/player_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/latar_sampul.dart';
import '../widgets/playlist_sheet.dart';
import 'artis_page.dart';
import 'lirik_page.dart';

/// Halaman pemutar layar penuh ("Sedang Diputar").
///
/// Dibuka dengan mengetuk bar pemutar. Berisi sampul besar, penggeser posisi,
/// tombol sebelumnya/putar/berikutnya, mode acak dan ulang, serta akses ke
/// antrean, playlist, dan timer tidur.
class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  /// Memutar [lagu] lalu langsung membuka halaman pemutar.
  ///
  /// Dipakai ketika pengguna mengetuk lagu di daftar mana pun. [antrean]
  /// adalah daftar asal lagu tersebut, sehingga lagu berikutnya diputar
  /// otomatis.
  static Future<void> putar(
    BuildContext context,
    Song lagu, {
    List<Song>? antrean,
  }) {
    // Pemuatan audio tidak ditunggu agar halaman terbuka seketika;
    // indikator memuat tampil pada tombol putar.
    pemutarGlobal.pilih(lagu, antrean: antrean, langsungPutar: true);
    return buka(context);
  }

  /// Membuka halaman dengan animasi meluncur dari bawah.
  static Future<void> buka(BuildContext context) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => const NowPlayingPage(),
        transitionsBuilder: (_, animasi, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: animasi, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pemutarGlobal,
      builder: (context, _) {
        final lagu = pemutarGlobal.lagu;
        final teks = Theme.of(context).textTheme;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'SEDANG DIPUTAR',
              style: teks.bodySmall?.copyWith(letterSpacing: 1.6),
            ),
            centerTitle: true,
            actions: [
              if (lagu != null)
                IconButton(
                  tooltip: 'Info lagu',
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () => _tampilkanInfo(context, lagu),
                ),
              IconButton(
                tooltip: 'Antrean',
                icon: const Icon(Icons.queue_music_rounded),
                onPressed: () => _tampilkanAntrean(context),
              ),
            ],
          ),
          body: Stack(
            children: [
              // Latar mengikuti warna sampul lagu, sama seperti halaman lirik.
              Positioned.fill(
                child: LatarSampul(url: lagu?.artworkBesar, kegelapan: 0.4),
              ),
              SafeArea(
                child: lagu == null
                    ? const Center(child: Text('Belum ada lagu yang diputar.'))
                    : _Isi(lagu: lagu),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Informasi lagu yang sebelumnya berada di halaman detail.
  void _tampilkanInfo(BuildContext context, Song lagu) {
    final teks = Theme.of(context).textTheme;

    Widget baris(String label, String nilai) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 100, child: Text(label, style: teks.bodySmall)),
              Expanded(child: Text(nilai, style: teks.titleMedium)),
            ],
          ),
        );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.latarLembut,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Info Lagu', style: teks.titleLarge),
              const SizedBox(height: 10),
              baris('Judul', lagu.trackName),
              baris('Artis', lagu.artistName),
              baris('Album', lagu.collectionName),
              baris('Genre', lagu.genre),
              baris('Durasi', lagu.durasi),
              baris('Tahun Rilis', lagu.tahunRilis),
              baris('Sumber', lagu.keteranganSumber),
            ],
          ),
        ),
      ),
    );
  }

  void _tampilkanAntrean(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.latarLembut,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: ListenableBuilder(
          listenable: pemutarGlobal,
          builder: (context, _) {
            final antrean = pemutarGlobal.antrean;
            final aktif = pemutarGlobal.indeks;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Antrean · ${antrean.length} lagu',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: antrean.length,
                    itemBuilder: (context, i) {
                      final item = antrean[i];
                      final sekarang = i == aktif;
                      return ListTile(
                        onTap: () => pemutarGlobal.lompatKe(i),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: item.artworkKecil == null
                                ? const ColoredBox(color: Color(0xFF1C1C22))
                                : Image.network(item.artworkKecil!,
                                    fit: BoxFit.cover),
                          ),
                        ),
                        title: Text(
                          item.trackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: sekarang ? AppTheme.aksen : Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(item.artistName, maxLines: 1),
                        trailing: sekarang
                            ? const Icon(Icons.graphic_eq_rounded,
                                color: AppTheme.aksen)
                            : Text(item.durasi),
                      );
                    },
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

class _Isi extends StatelessWidget {
  final Song lagu;

  const _Isi({required this.lagu});

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final lebar = MediaQuery.of(context).size.width - 56;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      children: [
        // Sampul besar.
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: lebar,
              height: lebar,
              child: lagu.artworkBesar == null
                  ? const ColoredBox(
                      color: Color(0xFF1C1C22),
                      child: Icon(Icons.music_note_rounded, size: 72),
                    )
                  : Image.network(
                      lagu.artworkBesar!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFF1C1C22),
                        child: Icon(Icons.music_note_rounded, size: 72),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Judul, artis, dan tombol favorit.
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lagu.trackName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: teks.titleLarge?.copyWith(fontSize: 23),
                  ),
                  const SizedBox(height: 2),
                  if (pemutarGlobal.galat != null)
                    Text(
                      pemutarGlobal.galat!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: teks.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  else
                    // Nama artis dapat diketuk untuk membuka halaman artis.
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ArtisPage(lagu: lagu, dariPemutar: true),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              lagu.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: teks.bodyMedium?.copyWith(
                                color: AppTheme.aksen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              size: 18, color: AppTheme.aksen),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _TombolFavorit(lagu: lagu),
          ],
        ),
        const SizedBox(height: 14),
        const _Penggeser(),
        const SizedBox(height: 6),
        // Tidak boleh const agar ikut dibangun ulang saat mode acak/ulang
        // berubah.
        // ignore: prefer_const_constructors
        _BarisKontrol(),
        const SizedBox(height: 18),
        Text(
          lagu.keteranganSumber,
          textAlign: TextAlign.center,
          style: teks.bodySmall,
        ),
        const SizedBox(height: 18),

        // Baris aksi tambahan.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            _AksiKecil(
              ikon: Icons.lyrics_outlined,
              label: 'Lirik',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LirikPage()),
              ),
            ),
            // ignore: prefer_const_constructors
            _TombolTimerTidur(),
            _AksiKecil(
              ikon: Icons.playlist_add_rounded,
              label: 'Playlist',
              onTap: () => tampilkanPilihPlaylist(context, lagu),
            ),
          ],
        ),
      ],
    );
  }
}

/// Penggeser posisi lagu beserta keterangan waktu berjalan dan durasi.
class _Penggeser extends StatefulWidget {
  const _Penggeser();

  @override
  State<_Penggeser> createState() => _PenggeserState();
}

class _PenggeserState extends State<_Penggeser> {
  /// Nilai sementara selama penggeser sedang ditarik, agar posisi tidak
  /// melompat-lompat mengikuti stream.
  double? _tarik;

  String _format(Duration d) {
    final menit = d.inMinutes;
    final detik = d.inSeconds % 60;
    return '$menit:${detik.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pemutar = pemutarGlobal.pemutar;

    return StreamBuilder<Duration?>(
      stream: pemutar.durationStream,
      initialData: pemutar.duration,
      builder: (context, snapDurasi) {
        final total = snapDurasi.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: pemutar.positionStream,
          initialData: pemutar.position,
          builder: (context, snapPosisi) {
            final posisi = snapPosisi.data ?? Duration.zero;
            final maks = total.inMilliseconds.toDouble();
            final nilai =
                _tarik ?? posisi.inMilliseconds.clamp(0, maks).toDouble();
            final berjalan = Duration(milliseconds: nilai.round());
            final sisa = total - berjalan;

            return Column(
              children: [
                Slider(
                  value: maks <= 0 ? 0 : nilai,
                  max: maks <= 0 ? 1 : maks,
                  onChanged:
                      maks <= 0 ? null : (v) => setState(() => _tarik = v),
                  onChangeEnd: (v) {
                    pemutar.seek(Duration(milliseconds: v.round()));
                    setState(() => _tarik = null);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_format(berjalan),
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      '-${_format(sisa.isNegative ? Duration.zero : sisa)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Tombol acak, sebelumnya, putar/jeda, berikutnya, dan ulang.
class _BarisKontrol extends StatelessWidget {
  const _BarisKontrol();

  @override
  Widget build(BuildContext context) {
    final pemutar = pemutarGlobal.pemutar;
    final mode = pemutarGlobal.modeUlang;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Acak',
          onPressed: pemutarGlobal.ubahAcak,
          icon: Icon(
            Icons.shuffle_rounded,
            color: pemutarGlobal.acak ? AppTheme.aksen : Colors.white60,
          ),
        ),
        IconButton(
          iconSize: 40,
          onPressed: pemutarGlobal.sebelumnya,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        StreamBuilder<PlayerState>(
          stream: pemutar.playerStateStream,
          initialData: pemutar.playerState,
          builder: (context, snapshot) {
            final kondisi = snapshot.data;
            final tahap = kondisi?.processingState ?? ProcessingState.idle;
            final memuat = tahap == ProcessingState.loading ||
                tahap == ProcessingState.buffering;
            final selesai = tahap == ProcessingState.completed;
            final sedangMain = kondisi?.playing ?? false;

            return Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: memuat
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Colors.black,
                      ),
                    )
                  : IconButton(
                      iconSize: 42,
                      onPressed: pemutarGlobal.galat == null
                          ? pemutarGlobal.tombolPutar
                          : null,
                      icon: Icon(
                        selesai
                            ? Icons.replay_rounded
                            : (sedangMain
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                        color: Colors.black,
                      ),
                    ),
            );
          },
        ),
        IconButton(
          iconSize: 40,
          onPressed: pemutarGlobal.berikutnya,
          icon: const Icon(Icons.skip_next_rounded),
        ),
        IconButton(
          tooltip: 'Ulang',
          onPressed: pemutarGlobal.ubahUlang,
          icon: Icon(
            mode == LoopMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: mode == LoopMode.off ? Colors.white60 : AppTheme.aksen,
          ),
        ),
      ],
    );
  }
}

/// Tombol hati yang mengikuti lagu yang sedang diputar.
class _TombolFavorit extends StatefulWidget {
  final Song lagu;

  const _TombolFavorit({required this.lagu});

  @override
  State<_TombolFavorit> createState() => _TombolFavoritState();
}

class _TombolFavoritState extends State<_TombolFavorit> {
  final FavoriteService _layanan = FavoriteService();
  bool _favorit = false;

  @override
  void initState() {
    super.initState();
    _periksa();
    versiFavorit.addListener(_periksa);
  }

  @override
  void didUpdateWidget(covariant _TombolFavorit lama) {
    super.didUpdateWidget(lama);
    if (lama.lagu.id != widget.lagu.id) _periksa();
  }

  @override
  void dispose() {
    versiFavorit.removeListener(_periksa);
    super.dispose();
  }

  Future<void> _periksa() async {
    final status = await _layanan.apakahFavorit(widget.lagu.id);
    if (mounted) setState(() => _favorit = status);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 28,
      onPressed: () => _layanan.ubahStatus(widget.lagu),
      icon: Icon(
        _favorit ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: _favorit ? AppTheme.aksen : Colors.white70,
      ),
    );
  }
}

/// Tombol timer tidur. Menampilkan sisa waktu bila timer sedang aktif.
class _TombolTimerTidur extends StatelessWidget {
  const _TombolTimerTidur();

  static const _pilihan = [15, 30, 45, 60];

  Future<void> _pilih(BuildContext context) async {
    final aktif = pemutarGlobal.batasTidur != null;
    final menit = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppTheme.latarLembut,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Timer Tidur',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Musik akan dijeda otomatis setelah waktu habis.',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            ..._pilihan.map((m) => ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text('$m menit'),
                  onTap: () => Navigator.pop(context, m),
                )),
            if (aktif)
              ListTile(
                leading:
                    const Icon(Icons.timer_off_outlined, color: AppTheme.aksen),
                title: const Text('Matikan timer'),
                onTap: () => Navigator.pop(context, 0),
              ),
          ],
        ),
      ),
    );
    if (menit == null) return;
    pemutarGlobal.aturTimerTidur(menit == 0 ? null : Duration(minutes: menit));
  }

  @override
  Widget build(BuildContext context) {
    final batas = pemutarGlobal.batasTidur;
    if (batas == null) {
      return _AksiKecil(
        ikon: Icons.bedtime_outlined,
        label: 'Timer',
        onTap: () => _pilih(context),
      );
    }

    // Sisa waktu diperbarui setiap detik.
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, _) {
        final sisa = batas.difference(DateTime.now());
        final menit = sisa.inMinutes;
        final detik = (sisa.inSeconds % 60).toString().padLeft(2, '0');
        return _AksiKecil(
          ikon: Icons.bedtime_rounded,
          label: sisa.isNegative ? 'Timer' : '$menit:$detik',
          aktif: true,
          onTap: () => _pilih(context),
        );
      },
    );
  }
}

class _AksiKecil extends StatelessWidget {
  final IconData ikon;
  final String label;
  final VoidCallback onTap;
  final bool aktif;

  const _AksiKecil({
    required this.ikon,
    required this.label,
    required this.onTap,
    this.aktif = false,
  });

  @override
  Widget build(BuildContext context) {
    final warna = aktif ? AppTheme.aksen : Colors.white70;
    return GlassPanel(
      onTap: onTap,
      radius: BorderRadius.circular(30),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 19, color: warna),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: warna, fontSize: 13)),
        ],
      ),
    );
  }
}
