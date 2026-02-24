/// The scanning mode for the document scanner.
///
/// Determines what type of document the scanner should look for.
enum ScanMode {
  /// Scan for license plate numbers only (existing ANPR behavior).
  plateOnly,

  /// Scan for STNK (Surat Tanda Nomor Kendaraan) documents.
  stnk,

  /// Scan for BPKB (Buku Pemilik Kendaraan Bermotor) documents.
  bpkb,

  /// Auto-detect the document type from OCR text.
  auto,
}
