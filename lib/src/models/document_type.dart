/// Internal classification result for a detected document.
enum DocumentType {
  /// STNK (Surat Tanda Nomor Kendaraan) — vehicle registration certificate.
  stnk,

  /// BPKB (Buku Pemilik Kendaraan Bermotor) — vehicle ownership book.
  bpkb,

  /// Unknown document type — classification was inconclusive.
  unknown,
}
