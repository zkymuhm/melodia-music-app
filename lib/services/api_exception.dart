/// Kesalahan yang sudah diterjemahkan menjadi pesan yang dapat dibaca
/// pengguna, sehingga lapisan antarmuka cukup menampilkan [pesan] tanpa
/// perlu mengetahui detail teknis penyebabnya.
class ApiException implements Exception {
  final String pesan;

  const ApiException(this.pesan);

  @override
  String toString() => pesan;
}
