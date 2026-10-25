import 'package:flutter/material.dart';

import 'glass.dart';

/// Tampilan saat aplikasi masih menunggu data dari server.
class LoadingView extends StatelessWidget {
  final String pesan;

  const LoadingView({super.key, this.pesan = 'Menyiapkan musik untukmu...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(height: 16),
            Text(pesan, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Tampilan saat permintaan ke API gagal, dengan tombol untuk mengulang.
class ErrorView extends StatelessWidget {
  final String pesan;
  final VoidCallback onCobaLagi;

  const ErrorView({super.key, required this.pesan, required this.onCobaLagi});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassPanel(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 44, color: Colors.white70),
              const SizedBox(height: 14),
              Text('Gagal memuat data',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                pesan,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCobaLagi,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tampilan saat permintaan berhasil tetapi tidak ada data yang diterima.
class EmptyView extends StatelessWidget {
  final String pesan;
  final IconData ikon;

  const EmptyView({
    super.key,
    required this.pesan,
    this.ikon = Icons.search_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 46, color: Colors.white38),
            const SizedBox(height: 14),
            Text(
              pesan,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
