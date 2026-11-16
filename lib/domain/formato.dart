/// Formatos y validaciones colombianas. Sin dependencias: fáciles de probar.
library;

/// 1234567 -> "$1.234.567"
String cop(double v) {
  final neg = v < 0;
  final s = v.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}\$${b.toString()}';
}

/// "25.000", "25,5", "$ 25.000", "25000" -> número.
/// Formato colombiano: punto = miles, coma = decimales.
/// Devuelve null si está vacío, no es número, es <= 0 o es absurdo.
double? parseMonto(String s) {
  final limpio = s.trim().replaceAll(RegExp(r'[^0-9,.]'), '');
  if (limpio.isEmpty) return null;
  final norm = limpio.contains(',')
      ? limpio.replaceAll('.', '').replaceAll(',', '.')
      : limpio.replaceAll('.', '');
  final v = double.tryParse(norm);
  if (v == null || !v.isFinite || v <= 0 || v > 999999999999) return null;
  return v;
}

/// Celular colombiano -> "57XXXXXXXXXX" (el formato que usa wa.me).
/// Devuelve '' si viene vacío (el teléfono es opcional) y null si no es un
/// celular válido de Colombia (10 dígitos que empiezan por 3).
String? normalizarTelefono(String s) {
  var d = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return '';
  if (d.startsWith('0057')) d = d.substring(4);
  if (d.length == 12 && d.startsWith('57')) d = d.substring(2);
  if (d.length == 10 && d.startsWith('3')) return '57$d';
  return null;
}

/// "573001234567" -> "300 123 4567"
String mostrarTelefono(String t) {
  final d = t.startsWith('57') && t.length == 12 ? t.substring(2) : t;
  if (d.length != 10) return d;
  return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
}

/// Minúsculas, sin tildes ni signos: para comparar texto escrito a mano.
String normalizarTexto(String s) {
  const de = 'áàäâãéèëêíìïîóòöôõúùüûñ';
  const a = 'aaaaaeeeeiiiiooooouuuun';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = de.indexOf(ch);
    b.write(i >= 0 ? a[i] : ch);
  }
  return b
      .toString()
      .replaceAll(RegExp(r'[¿?¡!.,;:"«»()]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// "Ana María Pérez" -> "Ana"
String primerNombre(String nombre) {
  final t = nombre.trim().split(RegExp(r'\s+'));
  return t.isEmpty ? nombre : t.first;
}
