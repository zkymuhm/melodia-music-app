// Pengujian dasar: memastikan kerangka aplikasi beserta bilah navigasi
// tiga tab berhasil dibangun saat aplikasi dijalankan.
import 'package:flutter_test/flutter_test.dart';

import 'package:melodia_myversion/main.dart';

void main() {
  testWidgets('Bilah navigasi menampilkan empat tab', (tester) async {
    await tester.pumpWidget(const MelodiaApp());

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Indie'), findsOneWidget);
    expect(find.text('Cari'), findsOneWidget);
    expect(find.text('Akun'), findsOneWidget);
  });
}
