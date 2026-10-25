import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/player_controller.dart';
import '../theme/app_theme.dart';

/// Bar pemutar yang menempel di bagian bawah layar: garis kemajuan tipis,
/// sampul album, judul lagu, nama artis, dan tombol putar/jeda.
///
/// Bentuknya sengaja dibuat rata tanpa sudut membulat agar menyatu dengan
/// bilah navigasi di bawahnya.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pemutarGlobal,
      builder: (context, _) {
        final lagu = pemutarGlobal.lagu;
        if (lagu == null) return const SizedBox.shrink();

        final teks = Theme.of(context).textTheme;

        // ClipRect menahan efek blur agar tidak merembet ke seluruh layar.
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                border: Border(top: BorderSide(color: AppTheme.kacaTepi)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tidak boleh const: widget const tidak dibangun ulang ketika
                  // pemutar memberi notifikasi, sehingga tampilannya membeku.
                  // ignore: prefer_const_constructors
                  _GarisKemajuan(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: lagu.artworkKecil == null
                                ? const ColoredBox(
                                    color: Color(0xFF1C1C22),
                                    child: Icon(Icons.music_note_rounded,
                                        size: 18, color: Colors.white24),
                                  )
                                : Image.network(
                                    lagu.artworkKecil!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const ColoredBox(
                                      color: Color(0xFF1C1C22),
                                      child: Icon(Icons.music_note_rounded,
                                          size: 18, color: Colors.white24),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                lagu.trackName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: teks.titleMedium,
                              ),
                              Text(
                                pemutarGlobal.galat ?? '${lagu.artistName} · ${lagu.keteranganSumber}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: teks.bodySmall?.copyWith(
                                  color: pemutarGlobal.galat != null
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ignore: prefer_const_constructors
                        _TombolPutar(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Garis tipis di tepi atas bar yang menunjukkan posisi putar.
class _GarisKemajuan extends StatelessWidget {
  const _GarisKemajuan();

  @override
  Widget build(BuildContext context) {
    final total = pemutarGlobal.pemutar.duration ?? Duration.zero;

    return StreamBuilder<Duration>(
      stream: pemutarGlobal.pemutar.positionStream,
      initialData: pemutarGlobal.pemutar.position,
      builder: (context, snapshot) {
        final posisi = snapshot.data ?? Duration.zero;
        final rasio = total.inMilliseconds == 0
            ? 0.0
            : (posisi.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
        return LinearProgressIndicator(
          value: rasio,
          minHeight: 2,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation(AppTheme.aksen),
        );
      },
    );
  }
}

/// Tombol putar/jeda pada bar, termasuk indikator saat audio masih dimuat.
class _TombolPutar extends StatelessWidget {
  const _TombolPutar();

  @override
  Widget build(BuildContext context) {
    if (pemutarGlobal.galat != null) {
      return const SizedBox(width: 48);
    }

    return StreamBuilder<PlayerState>(
      stream: pemutarGlobal.pemutar.playerStateStream,
      // playerStateStream adalah broadcast stream yang tidak mengirim ulang
      // nilai terakhirnya. Tanpa initialData, tampilan akan tertahan pada
      // kondisi kosong sampai ada perubahan berikutnya.
      initialData: pemutarGlobal.pemutar.playerState,
      builder: (context, snapshot) {
        final kondisi = snapshot.data;
        final tahap = kondisi?.processingState ?? ProcessingState.idle;
        final selesai = tahap == ProcessingState.completed;
        final sedangMain = kondisi?.playing ?? false;

        // Audio masih disiapkan: tampilkan indikator, bukan tombol.
        if (tahap == ProcessingState.idle ||
            tahap == ProcessingState.loading ||
            tahap == ProcessingState.buffering) {
          return const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          );
        }

        return IconButton(
          iconSize: 32,
          onPressed: pemutarGlobal.tombolPutar,
          icon: Icon(
            selesai
                ? Icons.replay_rounded
                : (sedangMain ? Icons.pause_rounded : Icons.play_arrow_rounded),
            color: Colors.white,
          ),
        );
      },
    );
  }
}
