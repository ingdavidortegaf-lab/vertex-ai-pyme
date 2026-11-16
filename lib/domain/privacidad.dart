/// Minimización de datos (Ley 1581 de 2012): antes de enviar una pregunta a
/// la IA se quitan correos, números largos (teléfonos, cédulas, cuentas) y
/// los nombres de los clientes guardados.
library;

String anonimizarPregunta(String pregunta, Iterable<String> nombresClientes) {
  var t = pregunta;
  t = t.replaceAll(
      RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+', unicode: true), '[correo]');
  t = t.replaceAll(RegExp(r'\+?\d[\d\s-]{5,}\d'), '[número]');

  // Nombres completos primero (los más largos), luego nombres sueltos.
  final completos = nombresClientes
      .map((n) => n.trim())
      .where((n) => n.length >= 3)
      .toSet()
      .toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final sueltos = <String>{};
  for (final n in completos) {
    for (final p in n.split(RegExp(r'\s+'))) {
      if (p.length >= 3) sueltos.add(p);
    }
  }
  for (final n in [...completos, ...sueltos]) {
    t = t.replaceAll(
      RegExp('(?<![\\p{L}])${RegExp.escape(n)}(?![\\p{L}])',
          caseSensitive: false, unicode: true),
      'un cliente',
    );
  }
  return t.length > 300 ? t.substring(0, 300) : t;
}
