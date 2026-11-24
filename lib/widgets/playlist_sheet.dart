import 'package:flutter/material.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../services/playlist_service.dart';
import '../theme/app_theme.dart';

/// Lembar bawah untuk memasukkan [lagu] ke salah satu playlist, atau
/// membuat playlist baru sekaligus.
Future<void> tampilkanPilihPlaylist(BuildContext context, Song lagu) async {
  final layanan = PlaylistService();
  // Messenger diambil lebih dulu karena context lembar bawah sudah tidak
  // berlaku setelah lembar ditutup.
  final messenger = ScaffoldMessenger.of(context);

  void kabari(String pesan) {
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(pesan),
      ),
    );
  }

  final dipilih = await showModalBottomSheet<Object>(
    context: context,
    backgroundColor: AppTheme.latarLembut,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => FutureBuilder<List<Playlist>>(
      future: layanan.ambilSemua(),
      builder: (context, snapshot) {
        final daftar = snapshot.data ?? const <Playlist>[];
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text('Tambahkan ke Playlist',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                ListTile(
                  leading: const _Ikon(ikon: Icons.add_rounded, aksen: true),
                  title: const Text('Playlist baru'),
                  onTap: () => Navigator.pop(context, 'baru'),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ...daftar.map(
                  (p) => ListTile(
                    leading: const _Ikon(ikon: Icons.queue_music_rounded),
                    title: Text(p.nama),
                    subtitle: Text('${p.lagu.length} lagu'),
                    onTap: () => Navigator.pop(context, p),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  if (dipilih == null || !context.mounted) return;

  Playlist tujuan;
  if (dipilih == 'baru') {
    final nama = await mintaNamaPlaylist(context);
    if (nama == null) return;
    tujuan = await layanan.buat(nama);
  } else {
    tujuan = dipilih as Playlist;
  }

  final berhasil = await layanan.tambahLagu(tujuan.id, lagu);
  kabari(berhasil
      ? 'Ditambahkan ke "${tujuan.nama}".'
      : 'Lagu sudah ada di "${tujuan.nama}".');
}

/// Dialog untuk mengisi nama playlist. Mengembalikan null bila dibatalkan.
Future<String?> mintaNamaPlaylist(
  BuildContext context, {
  String awal = '',
  String judul = 'Playlist Baru',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogNama(awal: awal, judul: judul),
  );
}

class _DialogNama extends StatefulWidget {
  final String awal;
  final String judul;

  const _DialogNama({required this.awal, required this.judul});

  @override
  State<_DialogNama> createState() => _DialogNamaState();
}

class _DialogNamaState extends State<_DialogNama> {
  late final TextEditingController _kolom =
      TextEditingController(text: widget.awal);

  @override
  void dispose() {
    _kolom.dispose();
    super.dispose();
  }

  void _simpan() {
    final nama = _kolom.text.trim();
    if (nama.isEmpty) return;
    Navigator.pop(context, nama);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.latarLembut,
      title: Text(widget.judul),
      content: TextField(
        controller: _kolom,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Nama playlist'),
        onSubmitted: (_) => _simpan(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _simpan, child: const Text('Simpan')),
      ],
    );
  }
}

class _Ikon extends StatelessWidget {
  final IconData ikon;
  final bool aksen;

  const _Ikon({required this.ikon, this.aksen = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: aksen ? AppTheme.aksen : Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(ikon, color: Colors.white),
    );
  }
}
