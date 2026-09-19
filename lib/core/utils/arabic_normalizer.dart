class ArabicNormalizer {
  static final RegExp _tashkeel =
      RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]');
  static final RegExp _spaces = RegExp(r'\s+');

  static String normalize(String? input) {
    if (input == null) return '';
    var value = input.trim();
    value = value.replaceAll(_tashkeel, '');
    value = value
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا');
    value = value.replaceAll('ـ', '');
    value = value.replaceAll(_spaces, ' ');
    return value;
  }
}
