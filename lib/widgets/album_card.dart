import 'package:flutter/material.dart';

import '../models/song.dart';

/// Kartu sampul album berukuran besar untuk daftar mendatar pada dashboard,
/// menyerupai baris "Dengarkan Sekarang" pada Apple Music.
class AlbumCard extends StatelessWidget {
  final Song lagu;
  final VoidCallback onTap;
  final double ukuran;

  const AlbumCard({
    super.key,
    required this.lagu,
    required this.onTap,
    this.ukuran = 132,
  });

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

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
                child: _sampul(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lagu.trackName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: teks.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              lagu.artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: teks.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sampul() {
    final url = lagu.artworkBesar;
    if (url == null) return const _SampulKosong();
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _SampulKosong(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _SampulKosong(),
    );
  }
}

class _SampulKosong extends StatelessWidget {
  const _SampulKosong();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF1C1C22),
      child: Icon(Icons.music_note_rounded, color: Colors.white24),
    );
  }
}
