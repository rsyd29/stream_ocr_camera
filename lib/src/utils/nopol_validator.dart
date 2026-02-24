/// Data class representing the confidence/accuracy result of OCR plate detection.
class NopolConfidence {
  /// Accuracy percentage from 0.0 to 100.0.
  final double percentage;

  /// The extracted plate number, or `null` if no valid plate was found.
  final String? plateNumber;

  /// The raw OCR text before cleaning.
  final String rawText;

  /// Whether the plate fully matches the Indonesian nopol format.
  final bool isValid;

  /// Creates a [NopolConfidence].
  const NopolConfidence({
    required this.percentage,
    this.plateNumber,
    required this.rawText,
    required this.isValid,
  });

  @override
  String toString() =>
      'NopolConfidence(percentage: ${percentage.toStringAsFixed(1)}%, '
      'plateNumber: $plateNumber, isValid: $isValid)';
}

/// Utility class for validating Indonesian license plate numbers (Nopol).
class NopolValidator {
  NopolValidator._();

  /// Indonesian plate format regex.
  /// Pattern: 1-2 uppercase letters, 1-4 digits, 0-3 uppercase letters.
  /// Examples: B 1234 ABC, DK 9999 XYZ, D 1 A, B 1 AB
  static final RegExp _nopolRegex = RegExp(
    r'^[A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{0,3}$',
  );

  /// Regex for prefix component: 1-2 uppercase letters at the start.
  static final RegExp _prefixRegex = RegExp(r'^[A-Z]{1,2}');

  /// Regex for digit component: 1-4 digits.
  static final RegExp _digitRegex = RegExp(r'\d{1,4}');

  /// Regex for suffix component: 1-3 uppercase letters at the end.
  static final RegExp _suffixRegex = RegExp(r'[A-Z]{1,3}$');

  /// Ideal nopol format with **required spaces** between components.
  /// Pattern: 1-2 letters SPACE 1-4 digits SPACE 1-3 letters.
  /// Examples: B 1234 ABC, DK 9999 XYZ, D 1 A
  static final RegExp _spacedNopolRegex = RegExp(
    r'^[A-Z]{1,2}\s\d{1,4}\s[A-Z]{1,3}$',
  );

  /// Partial spacing regex: at least one space present between components.
  static final RegExp _partialSpacedRegex = RegExp(
    r'^[A-Z]{1,2}\s\d{1,4}\s?[A-Z]{0,3}$|^[A-Z]{1,2}\s?\d{1,4}\s[A-Z]{1,3}$',
  );

  /// Cleans OCR output text for validation.
  ///
  /// Removes newlines, extra spaces, trims, and converts to uppercase.
  static String clean(String text) {
    return text
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toUpperCase()
        .trim();
  }

  /// Returns `true` if [text] matches the Indonesian license plate format.
  ///
  /// The text is automatically cleaned before validation.
  static bool isValid(String text) {
    final cleanText = clean(text);
    if (cleanText.isEmpty) return false;
    return _nopolRegex.hasMatch(cleanText);
  }

  /// Extracts a valid plate number from a multi-line OCR text block.
  ///
  /// Tries the full cleaned text first, then each line individually.
  /// Returns the first valid match, or `null` if none found.
  static String? extractPlate(String text) {
    // Try full text first
    final fullClean = clean(text);
    if (isValid(fullClean)) return fullClean;

    // Try each line
    final lines = text.split('\n');
    for (final line in lines) {
      final cleanLine = clean(line);
      if (isValid(cleanLine)) return cleanLine;
    }

    return null;
  }

  /// Calculates the **confidence/accuracy percentage** of an OCR result
  /// based on how well the text matches the Indonesian nopol regex pattern.
  ///
  /// The scoring system breaks down as follows:
  ///
  /// | Component              | Weight |
  /// |-----------------------|--------|
  /// | Prefix (1-2 huruf)     | 20%    |
  /// | Digit (1-4 angka)      | 30%    |
  /// | Suffix (1-3 huruf)     | 15%    |
  /// | Proper spacing         | 15%    |
  /// | Full regex match       | 20%    |
  ///
  /// **Spacing scoring:**
  /// - Full spaces (e.g. `B 1234 ABC`) → 15%
  /// - Partial spaces (e.g. `B1 ASD` or `B 1234ABC`) → 8%
  /// - No spaces (e.g. `B1ASD`) → 0%
  ///
  /// Returns a [NopolConfidence] with the computed percentage and metadata.
  ///
  /// If the text contains multiple lines, the **best match** is used.
  static NopolConfidence calculateConfidence(String text) {
    if (text.trim().isEmpty) {
      return NopolConfidence(percentage: 0, rawText: text, isValid: false);
    }

    // Collect candidates: full text + individual lines
    final candidates = <String>[clean(text)];
    if (text.contains('\n')) {
      for (final line in text.split('\n')) {
        final cleaned = clean(line);
        if (cleaned.isNotEmpty) candidates.add(cleaned);
      }
    }

    double bestScore = 0;

    for (final candidate in candidates) {
      final score = _scoreCandidate(candidate);
      if (score > bestScore) {
        bestScore = score;
      }
    }

    final plate = extractPlate(text);
    final valid = plate != null;

    return NopolConfidence(
      percentage: bestScore,
      plateNumber: plate,
      rawText: text,
      isValid: valid,
    );
  }

  /// Scores a single cleaned candidate string against nopol components.
  /// Returns a value from 0.0 to 100.0.
  static double _scoreCandidate(String candidate) {
    double score = 0;

    // 1. Prefix check (20%) — starts with 1-2 uppercase letters
    if (_prefixRegex.hasMatch(candidate)) {
      score += 20;
    }

    // 2. Digit check (30%) — contains 1-4 digits
    if (_digitRegex.hasMatch(candidate)) {
      score += 30;
    }

    // 3. Suffix check (15%) — ends with 1-3 uppercase letters
    //    Only score suffix if there are also digits (to avoid false positives
    //    on pure-letter strings).
    final withoutPrefix = candidate.replaceFirst(_prefixRegex, '').trim();
    if (withoutPrefix.isNotEmpty && _suffixRegex.hasMatch(withoutPrefix)) {
      // Verify suffix comes after digits
      final digitMatch = _digitRegex.firstMatch(withoutPrefix);
      if (digitMatch != null) {
        final afterDigits = withoutPrefix.substring(digitMatch.end).trim();
        if (afterDigits.isNotEmpty && _suffixRegex.hasMatch(afterDigits)) {
          score += 15;
        }
      }
    }

    // 4. Spacing check (15%) — proper Indonesian plate has spaces between
    //    prefix, digits, and suffix (e.g. "B 1234 ABC" not "B1234ABC").
    if (_spacedNopolRegex.hasMatch(candidate)) {
      // Full proper spacing: "B 1234 ABC"
      score += 15;
    } else if (_partialSpacedRegex.hasMatch(candidate)) {
      // Partial spacing: "B 1234ABC" or "B1 ASD"
      score += 8;
    }

    // 5. Full regex match (20%)
    if (_nopolRegex.hasMatch(candidate)) {
      score += 20;
    }

    return score;
  }
}
