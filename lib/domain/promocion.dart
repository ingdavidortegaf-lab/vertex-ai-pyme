/// Redactor de promociones para WhatsApp, Facebook e Instagram.
///
/// Funciona SIN internet: arma el texto con plantillas de mercadeo probadas
/// (gancho, beneficio, ahorro, urgencia y llamado a la acción) según el
/// estilo y la fecha (quincena, fin de semana, temporada). Si hay señal y la
/// IA en la nube está activa, la app le pide además una versión redactada por
/// el modelo; aquí solo vive la parte que se puede probar sin red.
library;

import 'formato.dart';
import 'documentos.dart';

enum EstiloPromo { alegre, urgente, cercano, combo, temporada }

const nombresEstilo = {
  EstiloPromo.alegre: 'Alegre',
  EstiloPromo.urgente: 'Última oportunidad',
  EstiloPromo.cercano: 'De vecino a vecino',
  EstiloPromo.combo: 'Combo',
  EstiloPromo.temporada: 'Temporada',
};

class ProductoPromo {
  final String nombre;
  final double precio; // precio de oferta
  final double precioAntes; // precio normal (0 si no aplica)
  const ProductoPromo(this.nombre, this.precio, [this.precioAntes = 0]);

  /// Porcentaje de descuento redondeado (0 si no hay rebaja real).
  int get descuento => precioAntes > precio && precioAntes > 0
      ? ((precioAntes - precio) / precioAntes * 100).round()
      : 0;
}

/// Ocasión comercial del momento, para que la promo "llegue a tiempo".
({String nombre, String gancho, String emoji}) ocasionDelMomento(DateTime d) {
  final dia = d.day;
  final finDeMes = DateTime(d.year, d.month + 1, 0).day;
  if (d.month == 12 && dia <= 24) {
    return (nombre: 'Navidad', gancho: 'Para la novena y la cena de Navidad', emoji: '🎄');
  }
  if (d.month == 12 || (d.month == 1 && dia <= 6)) {
    return (nombre: 'Fin de año', gancho: 'Para recibir el año con todo', emoji: '🎆');
  }
  if (d.month == 11 && dia >= 20) {
    return (nombre: 'Viernes negro', gancho: 'Precios de viernes negro en el barrio', emoji: '🖤');
  }
  if (d.month == 10 && dia >= 24) {
    return (nombre: 'Halloween', gancho: 'Dulces para los niños este 31', emoji: '🎃');
  }
  if (d.month == 9 && dia <= 21) {
    return (nombre: 'Amor y amistad', gancho: 'Para consentir a quien más quiere', emoji: '💛');
  }
  if (d.month == 5 && dia <= 14) {
    return (nombre: 'Día de la madre', gancho: 'Para celebrar a mamá', emoji: '💐');
  }
  if ((dia >= 14 && dia <= 16) || dia >= finDeMes - 1 || dia == 1) {
    return (nombre: 'Quincena', gancho: '¡Llegó la quincena y llegaron las ofertas!', emoji: '💰');
  }
  if (d.weekday >= DateTime.friday) {
    return (nombre: 'Fin de semana', gancho: 'Para el plan del fin de semana', emoji: '🎉');
  }
  return (nombre: 'Hoy', gancho: 'Ofertas de hoy', emoji: '🔥');
}

/// Arma el texto de la promoción. [variante] cambia la redacción para que
/// el botón «Otra versión» no repita siempre lo mismo.
String redactarPromocion({
  required PerfilNegocio negocio,
  required List<ProductoPromo> productos,
  EstiloPromo estilo = EstiloPromo.alegre,
  required DateTime ahora,
  String nota = '',
  bool domicilios = false,
  int variante = 0,
}) {
  final nombre = negocio.nombreVisible;
  final oc = ocasionDelMomento(ahora);
  String elige(List<String> l) => l[variante.abs() % l.length];
  final mejor = productos.fold<int>(0, (m, p) => p.descuento > m ? p.descuento : m);
  final total = productos.fold<double>(0, (s, p) => s + p.precio);
  final totalAntes = productos.fold<double>(0, (s, p) => s + (p.precioAntes > p.precio ? p.precioAntes : p.precio));

  final gancho = switch (estilo) {
    EstiloPromo.alegre => elige([
        '🔥 *¡OFERTAS EN $nombre!* 🔥',
        '🛒 *¡Llegaron los precios bajitos a $nombre!*',
        '✨ *¡Lo que estaba esperando, ahora más barato!* ✨',
      ]),
    EstiloPromo.urgente => elige([
        '⏰ *¡ÚLTIMAS UNIDADES!*',
        '🚨 *¡Solo por hoy en $nombre!*',
        '⏳ *¡Se acaba! Aproveche antes de que vuele*',
      ]),
    EstiloPromo.cercano => elige([
        '👋 *Vecino, vecina:* le tenemos algo especial',
        '🏡 *En $nombre pensamos en su familia*',
        '🤝 *Para nuestros clientes de siempre*',
      ]),
    EstiloPromo.combo => elige([
        '🎁 *¡COMBO ESPECIAL!*',
        '📦 *Lleve el combo y ahorre*',
        '🧺 *Combo listo para la casa*',
      ]),
    EstiloPromo.temporada => '${oc.emoji} *${oc.gancho}* ${oc.emoji}',
  };

  final b = StringBuffer()..writeln(gancho);
  if (mejor >= 5 && estilo != EstiloPromo.combo) {
    b.writeln('Hasta *$mejor % de descuento* 👇');
  }
  b.writeln();
  if (estilo == EstiloPromo.combo && productos.length > 1) {
    for (final p in productos) {
      b.writeln('✅ ${p.nombre}');
    }
    b.writeln();
    if (totalAntes > total + 0.5) {
      b.writeln('Antes ~${cop(totalAntes)}~ → *Todo por ${cop(total)}*');
      b.writeln('¡Se ahorra ${cop(totalAntes - total)}! 💸');
    } else {
      b.writeln('*Todo por ${cop(total)}*');
    }
  } else {
    for (final p in productos) {
      if (p.descuento > 0) {
        b.writeln('▪️ ${p.nombre}: ~${cop(p.precioAntes)}~ *${cop(p.precio)}* (-${p.descuento} %)');
      } else {
        b.writeln('▪️ ${p.nombre}: *${cop(p.precio)}*');
      }
    }
  }
  if (nota.trim().isNotEmpty) {
    b
      ..writeln()
      ..writeln('📌 ${nota.trim()}');
  }
  b.writeln();
  b.writeln(switch (estilo) {
    EstiloPromo.urgente => elige([
        'Válido hasta agotar existencias. ¡No se quede sin el suyo!',
        'Hoy hasta el cierre o hasta agotar existencias.',
      ]),
    EstiloPromo.cercano => elige([
        'Gracias por comprar en el barrio: así crecemos todos. 💚',
        'Aquí le atendemos como en casa. 💚',
      ]),
    _ => elige([
        'Aproveche, ¡son por tiempo limitado!',
        'Precios válidos hasta agotar existencias.',
      ]),
  });
  final dir = negocio.direccion.trim();
  b.write(elige([
    '📲 Pida por este WhatsApp${domicilios ? ' y se lo llevamos' : ''}',
    '📲 Escríbanos y se lo apartamos${domicilios ? ' o se lo llevamos' : ''}',
  ]));
  b.writeln(dir.isEmpty ? '.' : ' o visítenos en $dir.');
  final ciudad = _ciudad(dir);
  b.write('#${_etiqueta(nombre)} #ComprarEnElBarrio${ciudad.isEmpty ? '' : ' #$ciudad'}');
  return b.toString();
}

String _etiqueta(String s) {
  final limpio = s
      .replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚáéíóúÑñ0-9 ]'), '')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join();
  return limpio.isEmpty ? 'MiTienda' : limpio;
}

/// Ciudad de la dirección: lo que va después de la última coma, si no lleva
/// números («Cra 20 # 10-15, Bucaramanga» → «Bucaramanga»). Sirve en
/// cualquier parte del país, sin una lista fija de municipios.
String _ciudad(String direccion) {
  final partes = direccion.split(',');
  if (partes.length < 2) return '';
  final c = partes.last.trim();
  if (c.isEmpty || c.length > 40 || RegExp(r'[0-9#]').hasMatch(c)) return '';
  final e = _etiqueta(c);
  return e == 'MiTienda' ? '' : e;
}

/// Lo único que viaja a la IA en la nube para una promoción: nombres de
/// productos, precios, estilo y ocasión. Nada de clientes ni del negocio.
Map<String, dynamic> cuerpoPromocionIA(List<ProductoPromo> productos, EstiloPromo estilo, DateTime ahora) => {
      'modo': 'promocion',
      'estilo': nombresEstilo[estilo],
      'ocasion': ocasionDelMomento(ahora).nombre,
      'productos': [
        for (final p in productos.take(8))
          {
            'nombre': p.nombre.length > 40 ? p.nombre.substring(0, 40) : p.nombre,
            'precio': p.precio,
            if (p.precioAntes > p.precio) 'antes': p.precioAntes,
          }
      ],
    };
