import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'pages/root_page.dart';
import 'services/pengaturan_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Menyiapkan layanan latar belakang agar musik tetap berputar saat
  // aplikasi diminimalkan, sekaligus menampilkan notifikasi media berisi
  // judul, artis, sampul, dan tombol kontrol (sebelumnya/putar/berikutnya).
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.melodia_myversion.audio',
    androidNotificationChannelName: 'Pemutaran Musik',
    androidNotificationOngoing: true,
    // Ikon kecil di status bar: siluet putih logo Melodia.
    androidNotificationIcon: 'drawable/ic_stat_melodia',
  );

  // Pengaturan tampilan (misalnya latar bergerak) dimuat lebih dulu.
  await PengaturanService.muat();

  runApp(const MelodiaApp());
}

class MelodiaApp extends StatelessWidget {
  const MelodiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Melodia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.gelap,
      home: const RootPage(),
    );
  }
}
