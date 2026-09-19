/// Natural / "Explorer-like" filename compare.
///
/// Examples (ascending):
/// `…_01.mp4` < `…_01.1.mp4` < `…_02.mp4` < `…_010.mp4`
int naturalCompare(String a, String b) {
  final aLower = a.toLowerCase();
  final bLower = b.toLowerCase();
  if (aLower == bLower) return a.compareTo(b);

  final aStem = _stem(aLower);
  final bStem = _stem(bLower);
  final stemCmp = _compareVersioned(aStem, bStem);
  if (stemCmp != 0) return stemCmp;

  final aExt = _extension(aLower);
  final bExt = _extension(bLower);
  final extCmp = _compareNaturalChunked(aExt, bExt);
  if (extCmp != 0) return extCmp;

  return a.compareTo(b);
}

String _stem(String name) {
  final i = name.lastIndexOf('.');
  if (i <= 0) return name;
  return name.substring(0, i);
}

String _extension(String name) {
  final i = name.lastIndexOf('.');
  if (i <= 0) return '';
  return name.substring(i + 1);
}

/// Split on `.` so `01` comes before `01.1`, then compare each segment naturally.
int _compareVersioned(String a, String b) {
  final aParts = a.split('.');
  final bParts = b.split('.');
  final len = aParts.length < bParts.length ? aParts.length : bParts.length;

  for (var i = 0; i < len; i++) {
    final cmp = _compareNaturalChunked(aParts[i], bParts[i]);
    if (cmp != 0) return cmp;
  }

  // Fewer dotted segments first: `01` < `01.1`
  return aParts.length.compareTo(bParts.length);
}

int _compareNaturalChunked(String a, String b) {
  var i = 0;
  var j = 0;

  while (i < a.length && j < b.length) {
    final aDigit = _isDigit(a.codeUnitAt(i));
    final bDigit = _isDigit(b.codeUnitAt(j));

    if (aDigit && bDigit) {
      // Skip leading zeros but remember length for tie-breaks.
      final aStart = i;
      final bStart = j;
      while (i < a.length && a.codeUnitAt(i) == 0x30) {
        i++;
      }
      while (j < b.length && b.codeUnitAt(j) == 0x30) {
        j++;
      }

      final aNumStart = i;
      final bNumStart = j;
      while (i < a.length && _isDigit(a.codeUnitAt(i))) {
        i++;
      }
      while (j < b.length && _isDigit(b.codeUnitAt(j))) {
        j++;
      }

      final aLen = i - aNumStart;
      final bLen = j - bNumStart;
      if (aLen != bLen) return aLen.compareTo(bLen);

      for (var k = 0; k < aLen; k++) {
        final cmp = a.codeUnitAt(aNumStart + k).compareTo(
          b.codeUnitAt(bNumStart + k),
        );
        if (cmp != 0) return cmp;
      }

      // Same numeric value: fewer leading zeros first (`01` < `001`),
      // otherwise longer digit run first is already handled above.
      final aZeros = aNumStart - aStart;
      final bZeros = bNumStart - bStart;
      if (aZeros != bZeros) return aZeros.compareTo(bZeros);
      continue;
    }

    if (aDigit != bDigit) {
      // Prefer the side that ends the "base" name (non-digit continues as
      // extension-like text) — actually fall back to code-unit order, but
      // treat end-of-string as smaller so `01` < `01a` style cases work
      // via versioned split. Here just compare chars.
      return a.codeUnitAt(i).compareTo(b.codeUnitAt(j));
    }

    final cmp = a.codeUnitAt(i).compareTo(b.codeUnitAt(j));
    if (cmp != 0) return cmp;
    i++;
    j++;
  }

  return (a.length - i).compareTo(b.length - j);
}

bool _isDigit(int code) => code >= 0x30 && code <= 0x39;
