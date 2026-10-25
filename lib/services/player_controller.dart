import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';

/// Pengelola pemutar audio untuk seluruh aplikasi.
///
/// Dibuat satu objek bersama agar lagu tetap berputar ketika pengguna menutup
/// halaman detail dan kembali menjelajah, sama seperti perilaku bar pemutar
/// pada aplikasi musik pada umumnya.
class PlayerController extends ChangeNotifier {
  final AudioPlayer pemutar = AudioPlayer();

  Song? _lagu;
  bool _siap = false;
  String? _galat;

  Song? get lagu => _lagu;
  bool get siap => _siap;
  String? get galat => _galat;

  /// Memberi tahu pendengar dengan aman.
  ///
  /// Bila perubahan terjadi ketika Flutter sedang membangun frame, notifikasi
  /// ditunda sampai frame selesai. Tanpa penundaan ini Flutter melemparkan
  /// kesalahan karena widget tidak boleh diperbarui di tengah proses build.
  void _beritahu() {
    final fase = SchedulerBinding.instance.schedulerPhase;
    if (fase == SchedulerPhase.persistentCallbacks ||
        fase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
      // Frame berikutnya dijadwalkan secara eksplisit. Tanpa ini, callback di
      // atas tidak akan pernah dijalankan ketika aplikasi sedang diam.
      SchedulerBinding.instance.scheduleFrame();
    } else {
      notifyListeners();
    }
  }

  /// Menyiapkan lagu pada pemutar. Bila lagu yang sama dipilih kembali,
  /// proses pemuatan tidak diulang agar posisi putar tidak hilang.
  Future<void> pilih(Song lagu, {bool langsungPutar = false}) async {
    if (_lagu?.id == lagu.id) {
      if (langsungPutar && _siap) await pemutar.play();
      return;
    }

    _lagu = lagu;
    _siap = false;
    _galat = null;
    _beritahu();

    final url = lagu.urlAudio;
    if (url == null) {
      _galat = 'Lagu ini tidak menyediakan berkas audio.';
      _beritahu();
      return;
    }

    try {
      await pemutar.setUrl(url);
      _siap = true;
      _beritahu();
      if (langsungPutar) await pemutar.play();
    } catch (_) {
      _galat = 'Audio gagal dimuat.';
      _beritahu();
    }
  }

  /// Menangani tombol putar/jeda, termasuk mengulang dari awal bila
  /// pratinjau sudah selesai.
  Future<void> tombolPutar() async {
    final kondisi = pemutar.playerState;

    if (kondisi.processingState == ProcessingState.completed) {
      await pemutar.seek(Duration.zero);
      await pemutar.play();
    } else if (kondisi.playing) {
      await pemutar.pause();
    } else {
      await pemutar.play();
    }
  }

  @override
  void dispose() {
    pemutar.dispose();
    super.dispose();
  }
}

/// Objek pemutar yang dipakai bersama oleh seluruh halaman.
final PlayerController pemutarGlobal = PlayerController();
