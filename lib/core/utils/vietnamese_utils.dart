/// Utility functions for Vietnamese text processing

/// Remove Vietnamese diacritics (accents) from text
/// Converts "Sản phẩm" -> "San pham"
String removeDiacritics(String text) {
  const vietnamese = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
      'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
  const normalized = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
      'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

  var result = text;
  for (var i = 0; i < vietnamese.length; i++) {
    result = result.replaceAll(vietnamese[i], normalized[i]);
  }
  return result;
}

/// Normalize text for search (lowercase + remove diacritics)
/// Use this for both search query and searchable text
String normalizeForSearch(String text) {
  return removeDiacritics(text.toLowerCase());
}
