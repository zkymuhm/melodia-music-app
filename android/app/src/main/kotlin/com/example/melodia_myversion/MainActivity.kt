package com.example.melodia_myversion

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity (dari paket audio_service) menggantikan FlutterActivity
// agar layanan pemutar latar belakang dapat terhubung ke aplikasi.
class MainActivity : AudioServiceActivity()
