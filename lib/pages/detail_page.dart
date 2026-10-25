import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/favorite_service.dart';
import '../services/music_api_service.dart';
import '../services/player_controller.dart';
import '../widgets/glass.dart';
import '../widgets/mini_player.dart';
import '../widgets/state_views.dart';

/// Halaman detail lagu: sampul besar, informasi lagu, dan lirik.
///
/// Kendali pemutar tidak diletakkan di badan halaman, melainkan pada bar
/// pemutar di bagian bawah layar agar lagu tetap dapat dikendalikan ketika
/// pengguna kembali ke halaman sebelumnya.
class DetailPage extends StatefulWidget {
  final Song lagu;

  const DetailPage({super.key, required this.lagu});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final MusicApiService _api = MusicApiService();
  final FavoriteService _layananFavorit = FavoriteService();

  late Future<String?> _futureLirik;
  bool _favorit = false;

  @override
  void initState() {
    super.initState();
    _futureLirik =
        _api.ambilLirik(widget.lagu.artistName, widget.lagu.trackName);

    // Lagu disiapkan pada pemutar bersama, tetapi tidak langsung diputar
    // sehingga pengguna yang menekan tombol putar di bar.
    pemutarGlobal.pilih(widget.lagu);
    _periksaFavorit();
  }

  Future<void> _periksaFavorit() async {
    final status = await _layananFavorit.apakahFavorit(widget.lagu.id);
    if (mounted) setState(() => _favorit = status);
  }

  Future<void> _ubahFavorit() async {
    final status = await _layananFavorit.ubahStatus(widget.lagu);
    if (!mounted) return;
    setState(() => _favorit = status);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        duration: const Duration(seconds: 2),
        content: Text(
          status ? 'Ditambahkan ke favorit.' : 'Dihapus dari favorit.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lagu = widget.lagu;
    final teks = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _ubahFavorit,
            icon: Icon(
              _favorit
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: Stack(
        children: [
          const AuroraBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 230,
                      height: 230,
                      child: lagu.artworkBesar == null
                          ? const ColoredBox(
                              color: Color(0xFF1C1C22),
                              child: Icon(Icons.music_note_rounded, size: 56),
                            )
                          : Image.network(
                              lagu.artworkBesar!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                color: Color(0xFF1C1C22),
                                child:
                                    Icon(Icons.music_note_rounded, size: 56),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(lagu.trackName,
                    textAlign: TextAlign.center, style: teks.headlineLarge),
                const SizedBox(height: 4),
                Text(
                  lagu.artistName,
                  textAlign: TextAlign.center,
                  style: teks.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                GlassPanel(
                  child: Column(
                    children: [
                      _baris(context, 'Sumber', lagu.keteranganSumber),
                      _baris(context, 'Album', lagu.collectionName),
                      _baris(context, 'Genre', lagu.genre),
                      _baris(context, 'Durasi', lagu.durasi),
                      _baris(context, 'Tahun Rilis', lagu.tahunRilis),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('Lirik', style: teks.titleLarge),
                const SizedBox(height: 12),

                // FutureBuilder kedua: pengambilan lirik dari API terpisah.
                FutureBuilder<String?>(
                  future: _futureLirik,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: LoadingView(pesan: 'Mengambil lirik...'),
                      );
                    }
                    if (snapshot.hasError) {
                      return ErrorView(
                        pesan: snapshot.error.toString(),
                        onCobaLagi: () => setState(() {
                          _futureLirik = _api.ambilLirik(
                            lagu.artistName,
                            lagu.trackName,
                          );
                        }),
                      );
                    }
                    final lirik = snapshot.data;
                    if (lirik == null) {
                      return GlassPanel(
                        child: Text(
                          'Lirik untuk lagu ini belum tersedia pada '
                          'penyedia data.',
                          style: teks.bodySmall,
                        ),
                      );
                    }
                    return GlassPanel(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        lirik,
                        style: teks.bodyMedium?.copyWith(height: 1.7),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _baris(BuildContext context, String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child:
                Text(nilai, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}
