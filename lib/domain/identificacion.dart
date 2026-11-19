/// Identificación de clientes, proveedores y terceros: tipo de documento,
/// número (cédula o NIT con su dígito de verificación) y correo. Son los
/// datos que pide el contador y la factura electrónica de la DIAN.
library;

/// Tipos de documento más usados en Colombia.
const tiposDocumento = <String, String>{
  'CC': 'Cédula de ciudadanía',
  'NIT': 'NIT (empresa o negocio)',
  'CE': 'Cédula de extranjería',
  'PPT': 'Permiso por Protección Temporal',
  'PA': 'Pasaporte',
};

/// Nombre corto para mostrar (CC, NIT, CE…).
String siglaDocumento(String tipo) => tiposDocumento.containsKey(tipo) ? tipo : 'CC';

/// Deja solo dígitos (y letras en pasaporte o cédula de extranjería).
String limpiarDocumento(String tipo, String numero) {
  final s = numero.trim().toUpperCase();
  if (tipo == 'PA' || tipo == 'CE') return s.replaceAll(RegExp(r'[^0-9A-Z]'), '');
  return s.replaceAll(RegExp(r'[^0-9]'), '');
}

/// Dígito de verificación de un NIT (algoritmo de la DIAN, módulo 11).
int digitoVerificacion(String nit) {
  const pesos = [3, 7, 13, 17, 19, 23, 29, 37, 41, 43, 47, 53, 59, 67, 71];
  final d = nit.replaceAll(RegExp(r'[^0-9]'), '');
  var suma = 0;
  for (var i = 0; i < d.length && i < pesos.length; i++) {
    suma += int.parse(d[d.length - 1 - i]) * pesos[i];
  }
  final r = suma % 11;
  return r > 1 ? 11 - r : r;
}

/// Separa un NIT escrito como «900123456-7» o «9001234567» en (número, dv).
/// Si viene sin guion y con 10 dígitos, el último se toma como dígito de
/// verificación solo si cuadra.
(String, int?) partirNit(String texto) {
  final t = texto.trim();
  final guion = RegExp(r'^([0-9.\s]+)-\s*([0-9])$').firstMatch(t);
  if (guion != null) {
    return (guion.group(1)!.replaceAll(RegExp(r'[^0-9]'), ''), int.parse(guion.group(2)!));
  }
  final d = t.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length == 10 && digitoVerificacion(d.substring(0, 9)) == int.parse(d[9])) {
    return (d.substring(0, 9), int.parse(d[9]));
  }
  return (d, null);
}

/// Revisa el documento. Vacío es válido (es opcional). Devuelve el mensaje
/// de error en lenguaje sencillo, o null si está bien.
String? problemaDocumento(String tipo, String numero) {
  final t = numero.trim();
  if (t.isEmpty) return null;
  switch (tipo) {
    case 'NIT':
      final (n, dv) = partirNit(t);
      if (n.length < 8 || n.length > 10) return 'El NIT tiene 9 dígitos (sin contar el de verificación)';
      if (dv != null && dv != digitoVerificacion(n)) {
        return 'El dígito de verificación no cuadra: debería ser ${digitoVerificacion(n)}';
      }
      return null;
    case 'CC':
      final d = limpiarDocumento(tipo, t);
      if (d.length < 5 || d.length > 10) return 'La cédula tiene entre 5 y 10 números';
      return null;
    case 'PPT':
      final d = limpiarDocumento(tipo, t);
      if (d.length < 5 || d.length > 15) return 'Revisa el número del permiso';
      return null;
    default:
      final d = limpiarDocumento(tipo, t);
      if (d.length < 4 || d.length > 15) return 'Revisa el número del documento';
      return null;
  }
}

/// Cómo se guarda: NIT como «900123456-7» (con su dígito calculado); los
/// demás, solo el número.
String normalizarDocumento(String tipo, String numero) {
  final t = numero.trim();
  if (t.isEmpty) return '';
  if (tipo == 'NIT') {
    final (n, _) = partirNit(t);
    return '$n-${digitoVerificacion(n)}';
  }
  return limpiarDocumento(tipo, t);
}

String _miles(String d) {
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) b.write('.');
    b.write(d[i]);
  }
  return b.toString();
}

/// Para mostrar: «NIT 900.123.456-7», «CC 1.118.555.444».
String mostrarDocumento(String tipo, String numero) {
  if (numero.trim().isEmpty) return '';
  final sigla = siglaDocumento(tipo);
  if (sigla == 'NIT') {
    final p = numero.split('-');
    return 'NIT ${_miles(p.first)}${p.length > 1 ? '-${p[1]}' : ''}';
  }
  if (sigla == 'CC') return 'CC ${_miles(numero)}';
  return '$sigla $numero';
}

/// Correo opcional: vacío es válido.
String? problemaCorreo(String correo) {
  final c = correo.trim();
  if (c.isEmpty) return null;
  if (c.length > 120 || !RegExp(r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$').hasMatch(c)) {
    return 'Revisa el correo (ej.: nombre@gmail.com)';
  }
  return null;
}

String normalizarCorreo(String correo) => correo.trim().toLowerCase();

/// ¿Tiene lo que pide una factura a nombre propio? (documento y correo).
bool datosParaFactura({required String documento, required String correo}) =>
    documento.trim().isNotEmpty && correo.trim().isNotEmpty;

/// Clases de terceros: a quién se le compra o se le paga.
const clasesTercero = <String, String>{
  'proveedor': 'Proveedor',
  'servicios': 'Servicios (luz, agua, internet)',
  'arriendo': 'Arrendador',
  'empleado': 'Empleado o ayudante',
  'otro': 'Otro',
};

String nombreClase(String clase) => (clasesTercero[clase] ?? 'Otro').split(' (').first;
