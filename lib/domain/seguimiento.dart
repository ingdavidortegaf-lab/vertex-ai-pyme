/// Seguimiento de clientes (un CRM sencillo para la tienda de barrio).
///
/// Con las compras que ya registra la app se arman grupos para escribirles
/// por WhatsApp en el momento justo: los que hace rato no vienen, los mejores
/// clientes, los nuevos y los que llevan mucho tiempo sin aparecer. Solo se
/// sugiere escribir a quien autorizó la comunicación comercial (Ley 1581).
library;

import 'formato.dart';

class ResumenCliente {
  final String id;
  final String nombre;
  final String telefono;
  final int compras;
  final double total;
  final DateTime? primera;
  final DateTime? ultima;
  final double saldo;
  final bool autorizo;
  final DateTime? contactado; // última vez que se le escribió desde aquí
  const ResumenCliente({
    required this.id,
    required this.nombre,
    this.telefono = '',
    this.compras = 0,
    this.total = 0,
    this.primera,
    this.ultima,
    this.saldo = 0,
    this.autorizo = false,
    this.contactado,
  });

  int? diasSinComprar(DateTime ahora) => ultima == null
      ? null
      : DateTime(ahora.year, ahora.month, ahora.day)
          .difference(DateTime(ultima!.year, ultima!.month, ultima!.day))
          .inDays;

  double get ticketPromedio => compras == 0 ? 0 : total / compras;
}

enum Grupo { extranados, mejores, nuevos, perdidos }

const nombresGrupo = {
  Grupo.extranados: 'Hace rato no vienen',
  Grupo.mejores: 'Mejores clientes',
  Grupo.nuevos: 'Clientes nuevos',
  Grupo.perdidos: 'Más de 3 meses sin venir',
};

const ayudaGrupo = {
  Grupo.extranados: 'Compraban y llevan entre 3 y 12 semanas sin volver. Un saludo a tiempo los recupera.',
  Grupo.mejores: 'Los que más le compran. Agradézcales y deles un detalle: son su base.',
  Grupo.nuevos: 'Primera compra en las últimas 2 semanas. Deles la bienvenida para que vuelvan.',
  Grupo.perdidos: 'Más de 90 días sin comprar. Una oferta especial puede traerlos de vuelta.',
};

/// Reparte a los clientes en grupos. Un cliente puede estar en «mejores» y
/// también en «hace rato no vienen» (es justo a quien más vale recuperar).
Map<Grupo, List<ResumenCliente>> agruparClientes(List<ResumenCliente> l, DateTime ahora) {
  final conCompras = l.where((c) => c.compras > 0).toList()..sort((a, b) => b.total.compareTo(a.total));
  final cuantosMejores = conCompras.isEmpty ? 0 : (conCompras.length * 0.2).ceil().clamp(1, 20);
  final mejores = conCompras.where((c) => c.compras >= 3).take(cuantosMejores).toList();
  final g = {
    Grupo.extranados: <ResumenCliente>[],
    Grupo.mejores: mejores,
    Grupo.nuevos: <ResumenCliente>[],
    Grupo.perdidos: <ResumenCliente>[],
  };
  for (final c in conCompras) {
    final d = c.diasSinComprar(ahora)!;
    final desdePrimera = c.primera == null ? 999 : ahora.difference(c.primera!).inDays;
    if (desdePrimera <= 14 && c.compras <= 2) {
      g[Grupo.nuevos]!.add(c);
    } else if (d > 90) {
      g[Grupo.perdidos]!.add(c);
    } else if (d >= 21) {
      g[Grupo.extranados]!.add(c);
    }
  }
  // Primero a quien más compra (vale más recuperarlo).
  g[Grupo.extranados]!.sort((a, b) => b.total.compareTo(a.total));
  g[Grupo.perdidos]!.sort((a, b) => b.total.compareTo(a.total));
  return g;
}

/// Mensaje sugerido para cada grupo, en tono de vecino (usted).
String mensajeSeguimiento(Grupo g, ResumenCliente c, {required String negocio, int variante = 0}) {
  final n = primerNombre(c.nombre);
  String elige(List<String> l) => l[variante.abs() % l.length];
  return switch (g) {
    Grupo.extranados => elige([
        'Hola $n 👋, le saludamos de *$negocio*. Hace días no lo vemos por aquí y lo extrañamos. '
            'Esta semana tenemos productos frescos y buenos precios. ¿Le apartamos algo?',
        'Hola $n, ¿cómo está? En *$negocio* nos acordamos de usted. Si necesita algo para la casa, '
            'escríbanos por aquí y se lo tenemos listo. 😊',
      ]),
    Grupo.mejores => elige([
        'Hola $n 🌟, gracias por ser de los mejores clientes de *$negocio*. Como agradecimiento, '
            'en su próxima compra tiene un detalle especial. ¡Lo esperamos!',
        'Hola $n, en *$negocio* queremos agradecerle por su confianza de siempre 💚. '
            'Cuando venga, pregunte por su sorpresa de cliente preferido.',
      ]),
    Grupo.nuevos => elige([
        'Hola $n, ¡gracias por comprar en *$negocio*! 🙌 Guarde este número: por aquí puede '
            'hacernos pedidos y le avisamos de las ofertas.',
        'Bienvenido(a), $n 😊. En *$negocio* estamos para servirle. Escríbanos por aquí cuando '
            'necesite algo y se lo tenemos listo.',
      ]),
    Grupo.perdidos => elige([
        'Hola $n, hace mucho no sabemos de usted 😊. En *$negocio* le tenemos una oferta de regreso: '
            'muestre este mensaje en su próxima compra.',
        'Hola $n, ¡lo extrañamos en *$negocio*! Vuelva esta semana y le damos un precio especial. '
            'Lo esperamos.',
      ]),
  };
}

/// Para no cansar al cliente: no se sugiere escribir de nuevo antes de 7 días.
bool puedeEscribir(ResumenCliente c, DateTime ahora) =>
    c.autorizo &&
    c.telefono.trim().isNotEmpty &&
    (c.contactado == null || ahora.difference(c.contactado!).inDays >= 7);

/// «hoy», «ayer» o «hace N días».
String haceDias(int d) => d <= 0 ? 'hoy' : (d == 1 ? 'ayer' : 'hace $d días');
