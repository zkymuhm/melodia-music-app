import 'package:flutter/material.dart';

import '../models/song.dart';

/// Satu baris daftar lagu bergaya Apple Music: sampul kecil persegi,
/// judul, nama artis, dan durasi.
class SongTile extends StatelessWidget {
  final Song lagu;
  final VoidCallback onTap;
  final int? nomor;

  const SongTile({
    super.key,
    required this.lagu,
    required this.onTap,
    this.nomor,
  });

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        child: Row(
          children: [
            if (nomor != null) ...[
              SizedBox(
                width: 22,
                child: Text('$nomor', style: teks.bodySmall),
              ),
              const SizedBox(width: 6),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 52,
                child: lagu.artworkKecil == null
                    ? const ColoredBox(
                        color: Color(0xFF1C1C22),
                        child: Icon(Icons.music_note_rounded,
                            color: Colors.white24, size: 20),
                      )
                    : Image.network(
                        lagu.artworkKecil!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF1C1C22),
                          child: Icon(Icons.music_note_rounded,
                              color: Colors.white24, size: 20),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
            const SizedBox(width: 10),
            Text(lagu.durasi, style: teks.bodySmall),
          ],
        ),
      ),
    );
  }
}
