import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/song.dart';
import 'lirik_service.dart';
import 'riwayat_service.dart';

/// Pengelola pemutar audio untuk seluruh aplikasi.
///
/// Dibuat satu objek bersama agar lagu tetap berputar ketika pengguna menutup
/// halaman pemutar dan kembali menjelajah, sama seperti perilaku bar pemutar
/// pada aplikasi musik pada umumnya.
///
/// Sejak versi UAS, pemutar tidak lagi memegang satu lagu, melainkan sebuah
/// antrean. Lagu berikutnya diputar otomatis ketika lagu selesai, dan setiap
/// lagu membawa [MediaItem] sehingga muncul sebagai notifikasi media
/// (judul, artis, sampul, tombol kontrol) di panel notifikasi dan layar kunci.
class PlayerController extends ChangeNotifier {
  PlayerController() {
    // Indeks berubah saat lagu berganti otomatis, lewat tombol notifikasi,
    // atau lewat tombol next/previous di aplikasi.
    pemutar.currentIndexStream.listen((indeks) {
      if (indeks == null || indeks == _indeks) return;
      _indeks = indeks;
      _galat = null;
      _beritahu();
      // Lagu berganti di tengah pemutaran (otomatis atau tombol berikutnya).
      if (pemutar.playing) _catatRiwayat();
    });

    // Lagu baru dicatat ke riwayat ketika benar-benar mulai diputar,
    // bukan sekadar dipilih.
    pemutar.playingStream.listen((main) {
      if (main) _catatRiwayat();
    });

    // Kesalahan pemutaran (misalnya berkas tidak dapat diunduh) dilaporkan
    // lewat stream ini, bukan lewat exception biasa.
    pemutar.playbackEventStream.listen(
      (_) {},
      onError: (Object _, StackTrace __) {
        _galat = 'Audio gagal dimuat.';
        _beritahu();
      },
    );

    pemutar.shuffleModeEnabledStream.listen((_) => _beritahu());
    pemutar.loopModeStream.listen((_) => _beritahu());
  }

  final AudioPlayer pemutar = AudioPlayer(
    // Secara bawaan pemutar Android (ExoPlayer) menunggu 2,5 detik audio
    // terunduh sebelum mulai berbunyi, sehingga lagu terasa "loading" dulu.
    // Dengan 0,5 detik, lagu langsung terdengar begitu potongan pertamanya
    // tiba, mirip Spotify. Setelah sempat tersendat, pemutar menunggu
    // 1,5 detik agar tidak putus-sambung berulang kali.
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        bufferForPlaybackDuration: Duration(milliseconds: 500),
        bufferForPlaybackAfterRebufferDuration: Duration(milliseconds: 1500),
      ),
    ),
  );

  List<Song> _antrean = const [];
  int _indeks = 0;
  bool _siap = false;
  String? _galat;
  ConcatenatingAudioSource? _sumber;

  Timer? _timerTidur;
  DateTime? _batasTidur;

  final RiwayatService _riwayat = RiwayatService();
  String? _terakhirDicatat;

  void _catatRiwayat() {
    final sekarang = lagu;
    if (sekarang == null || sekarang.id == _terakhirDicatat) return;
    _terakhirDicatat = sekarang.id;
    _riwayat.catat(sekarang);
    // Lirik diambil di latar sejak lagu mulai diputar, sehingga halaman
    // Lirik biasanya sudah siap ketika dibuka.
    LirikService().siapkan(sekarang);
  }

  /// Daftar lagu yang sedang dimainkan, sesuai urutan aslinya.
  List<Song> get antrean => List.unmodifiable(_antrean);

  /// Posisi lagu yang sedang dimainkan di dalam [antrean].
  int get indeks => _indeks;

  Song? get lagu {
    if (_antrean.isEmpty) return null;
    if (_indeks < 0 || _indeks >= _antrean.length) return _antrean.first;
    return _antrean[_indeks];
  }

  bool get siap => _siap;
  String? get galat => _galat;
  bool get acak => pemutar.shuffleModeEnabled;
  LoopMode get modeUlang => pemutar.loopMode;

  /// Waktu pemutar akan berhenti otomatis. Null bila timer tidur tidak aktif.
  DateTime? get batasTidur => _batasTidur;

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

  /// Mengubah satu lagu menjadi sumber audio beserta data notifikasinya.
  AudioSource _jadikanSumber(Song lagu) {
    final sampul = lagu.artworkBesar ?? lagu.artworkKecil;
    return AudioSource.uri(
      Uri.parse(lagu.urlAudio!),
      tag: MediaItem(
        id: '${lagu.sumber.name}-${lagu.id}',
        title: lagu.trackName,
        artist: lagu.artistName,
        album: lagu.collectionName,
        artUri: sampul == null ? null : Uri.tryParse(sampul),
        // Durasi iTunes adalah durasi lagu asli, padahal yang diputar hanya
        // pratinjau 30 detik, sehingga tidak dikirim ke notifikasi.
        duration: lagu.dapatDiputarPenuh && lagu.durasiDetik > 0
            ? Duration(seconds: lagu.durasiDetik)
            : null,
      ),
    );
  }

  bool _antreanSama(List<Song> daftar) {
    if (daftar.length != _antrean.length) return false;
    for (var i = 0; i < daftar.length; i++) {
      if (daftar[i].id != _antrean[i].id) return false;
    }
    return true;
  }

  /// Menyiapkan [lagu] pada pemutar.
  ///
  /// [antrean] adalah daftar asal lagu tersebut (misalnya hasil pencarian
  /// atau isi playlist). Setelah [lagu] selesai, lagu berikutnya pada
  /// antrean diputar otomatis. Bila lagu yang sama dipilih kembali, proses
  /// pemuatan tidak diulang agar posisi putar tidak hilang.
  Future<void> pilih(
    Song lagu, {
    List<Song>? antrean,
    bool langsungPutar = false,
  }) async {
    if (this.lagu?.id == lagu.id && _galat == null) {
      if (langsungPutar && _siap) pemutar.play();
      return;
    }

    if (lagu.urlAudio == null) {
      await pemutar.stop();
      _antrean = [lagu];
      _indeks = 0;
      _siap = false;
      _sumber = null;
      _galat = 'Lagu ini tidak menyediakan berkas audio.';
      _beritahu();
      return;
    }

    // Lagu tanpa berkas audio dibuang agar antrean tidak tersendat.
    final daftar =
        (antrean ?? [lagu]).where((item) => item.urlAudio != null).toList();
    var awal = daftar.indexWhere((item) => item.id == lagu.id);
    if (awal < 0) {
      daftar.insert(0, lagu);
      awal = 0;
    }

    // Antrean tidak berubah: cukup lompat ke lagu yang dipilih.
    if (_siap && _antreanSama(daftar)) {
      _indeks = awal;
      _galat = null;
      _beritahu();
      await pemutar.seek(Duration.zero, index: awal);
      if (langsungPutar) {
        pemutar.play();
        _catatRiwayat();
      }
      return;
    }

    _antrean = daftar;
    _indeks = awal;
    _siap = false;
    _galat = null;
    _beritahu();

    final sumber = ConcatenatingAudioSource(
      children: daftar.map(_jadikanSumber).toList(),
    );
    _sumber = sumber;

    try {
      await pemutar.setAudioSource(sumber, initialIndex: awal);
      // Pengguna sudah memilih lagu lain selama proses pemuatan.
      if (!identical(_sumber, sumber)) return;
      _siap = true;
      _beritahu();
      // play() tidak di-await karena Future-nya baru selesai saat lagu
      // dijeda atau dihentikan.
      if (langsungPutar) {
        pemutar.play();
        _catatRiwayat();
      }
    } on PlayerInterruptedException {
      // Pemuatan dibatalkan oleh pemilihan lagu berikutnya. Bukan kesalahan.
    } catch (_) {
      if (!identical(_sumber, sumber)) return;
      _galat = 'Audio gagal dimuat.';
      _beritahu();
    }
  }

  /// Memutar seluruh [daftar] dalam urutan acak.
  Future<void> putarAcak(List<Song> daftar) async {
    if (daftar.isEmpty) return;
    final mulai = daftar[Random().nextInt(daftar.length)];
    await pilih(mulai, antrean: daftar, langsungPutar: true);
    await pemutar.shuffle();
    await pemutar.setShuffleModeEnabled(true);
  }

  /// Menambahkan lagu ke akhir antrean. Mengembalikan false bila lagu sudah
  /// ada di antrean.
  Future<bool> tambahKeAntrean(Song lagu) async {
    if (lagu.urlAudio == null) return false;
    final sumber = _sumber;
    if (sumber == null || !_siap) {
      await pilih(lagu);
      return true;
    }
    if (_antrean.any((item) => item.id == lagu.id)) return false;
    _antrean = [..._antrean, lagu];
    await sumber.add(_jadikanSumber(lagu));
    _beritahu();
    return true;
  }

  /// Menangani tombol putar/jeda, termasuk mengulang dari awal bila
  /// lagu sudah selesai.
  Future<void> tombolPutar() async {
    final kondisi = pemutar.playerState;

    if (kondisi.processingState == ProcessingState.completed) {
      await pemutar.seek(Duration.zero);
      pemutar.play();
    } else if (kondisi.playing) {
      await pemutar.pause();
    } else {
      pemutar.play();
    }
  }

  Future<void> berikutnya() async {
    if (!pemutar.hasNext) return;
    await pemutar.seekToNext();
    pemutar.play();
  }

  /// Seperti aplikasi musik umumnya: bila lagu sudah berjalan lebih dari
  /// 3 detik, tombol ini mengulang lagu dari awal lebih dulu.
  Future<void> sebelumnya() async {
    if (pemutar.position > const Duration(seconds: 3) || !pemutar.hasPrevious) {
      await pemutar.seek(Duration.zero);
    } else {
      await pemutar.seekToPrevious();
    }
    pemutar.play();
  }

  /// Melompat ke lagu ke-[i] pada antrean.
  Future<void> lompatKe(int i) async {
    if (i < 0 || i >= _antrean.length) return;
    await pemutar.seek(Duration.zero, index: i);
    pemutar.play();
  }

  Future<void> ubahAcak() async {
    final aktif = !pemutar.shuffleModeEnabled;
    if (aktif) await pemutar.shuffle();
    await pemutar.setShuffleModeEnabled(aktif);
  }

  /// Berganti mode ulang: mati → ulang semua → ulang satu lagu → mati.
  Future<void> ubahUlang() async {
    final berikut = switch (pemutar.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await pemutar.setLoopMode(berikut);
  }

  /// Mengaktifkan timer tidur. Setelah [durasi] berlalu musik dijeda
  /// otomatis. Kirim null untuk mematikan timer.
  void aturTimerTidur(Duration? durasi) {
    _timerTidur?.cancel();
    _timerTidur = null;
    _batasTidur = null;

    if (durasi != null) {
      _batasTidur = DateTime.now().add(durasi);
      _timerTidur = Timer(durasi, () {
        pemutar.pause();
        _timerTidur = null;
        _batasTidur = null;
        _beritahu();
      });
    }
    _beritahu();
  }

  @override
  void dispose() {
    _timerTidur?.cancel();
    pemutar.dispose();
    super.dispose();
  }
}

/// Objek pemutar yang dipakai bersama oleh seluruh halaman.
final PlayerController pemutarGlobal = PlayerController();
