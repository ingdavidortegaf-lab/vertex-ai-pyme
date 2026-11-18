/// Formatos y validaciones colombianas. Sin dependencias: fáciles de probar.
library;

import 'paises.dart';

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

/// Celular -> número completo con indicativo y sin «+» (el formato que usa
/// wa.me), por ejemplo "573001234567" o "13051234567".
/// - [pais]: indicativo elegido en el formulario (Colombia por defecto).
/// - Si se escribe con «+» o «00», se toma como número internacional
///   completo, de cualquier país.
/// Devuelve '' si viene vacío (el teléfono es opcional) y null si no es
/// válido. En Colombia solo se aceptan celulares (10 dígitos que empiezan
/// por 3), porque WhatsApp no funciona con fijos.
String? normalizarTelefono(String s, {String pais = '57'}) {
  final crudo = s.trim();
  var d = crudo.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return '';
  final internacional = crudo.startsWith('+') || d.startsWith('00');
  if (d.startsWith('00')) d = d.substring(2);
  if (internacional) return _completoValido(d) ? d : null;
  if (pais == '57') {
    if (d.length == 12 && d.startsWith('57')) d = d.substring(2);
    if (d.length == 10 && d.startsWith('3')) return '57$d';
    return null;
  }
  final opciones = paises.where((p) => p.codigo == pais);
  final min = opciones.isEmpty ? 6 : opciones.map((p) => p.min).reduce((a, b) => a < b ? a : b);
  final max = opciones.isEmpty ? 12 : opciones.map((p) => p.max).reduce((a, b) => a > b ? a : b);
  // Ya trae el indicativo: "1 305 123 4567" con Estados Unidos elegido.
  if (d.startsWith(pais) && d.length - pais.length >= min && d.length - pais.length <= max) {
    return d;
  }
  if (d.length >= min && d.length <= max) return '$pais$d';
  return null;
}

/// Número completo (con indicativo) entre 8 y 15 dígitos (norma E.164).
bool _completoValido(String d) {
  if (d.length < 8 || d.length > 15) return false;
  if (d.startsWith('57')) return d.length == 12 && d[2] == '3';
  return paisDeNumero(d) != null || d.length >= 10;
}

/// "573001234567" -> "300 123 4567" (Colombia, sin indicativo);
/// "13051234567" -> "+1 305 123 4567"; otros países con su indicativo.
String mostrarTelefono(String t) {
  if (t.startsWith('57') && t.length == 12) {
    final d = t.substring(2);
    return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
  }
  if (t.length == 10 && t.startsWith('3')) {
    return '${t.substring(0, 3)} ${t.substring(3, 6)} ${t.substring(6)}';
  }
  final p = t.length > 10 ? paisDeNumero(t) : null;
  if (p == null) return t;
  final n = t.substring(p.codigo.length);
  return '+${p.codigo} ${_agrupar(n)}';
}

/// Parte un número nacional para que se lea fácil: 305 123 4567 / 6123 4567.
String _agrupar(String n) {
  if (n.length == 10) return '${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}';
  if (n.length == 9) return '${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}';
  if (n.length == 8) return '${n.substring(0, 4)} ${n.substring(4)}';
  return n;
}

/// Separa un número guardado en (indicativo, número nacional) para
/// mostrarlo en un formulario con el selector de país.
(String pais, String nacional) separarTelefono(String t) {
  if (t.isEmpty) return ('57', '');
  if (t.startsWith('57') && t.length == 12) return ('57', t.substring(2));
  if (t.length == 10 && t.startsWith('3')) return ('57', t);
  final p = paisDeNumero(t);
  if (p == null || t.length <= 10) return ('57', t);
  return (p.codigo, t.substring(p.codigo.length));
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
