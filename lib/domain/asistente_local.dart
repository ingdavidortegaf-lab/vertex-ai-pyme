/// Asistente SIN conexión: entiende las preguntas más comunes con reglas
/// simples y responde con los datos guardados en el celular. Garantiza que el
/// asistente nunca "falle" cuando no hay señal.
library;

import 'formato.dart';
import 'resumen.dart';

export 'formato.dart' show cop;

enum Intencion {
  ventasHoy,
  ventasSemana,
  ventasMes,
  quienDebe,
  mejoresClientes,
  gastosMes,
  mensajeCliente,
  resumen,
  general,
}

class RespuestaLocal {
  final String texto;

  /// Si la respuesta trae un mensaje listo para WhatsApp.
  final String? telefono;
  final String? mensajeWhatsApp;
  const RespuestaLocal(this.texto, {this.telefono, this.mensajeWhatsApp});
}

bool _alguna(String t, List<String> claves) => claves.any(t.contains);

Intencion detectarIntencion(String pregunta) {
  final t = normalizarTexto(pregunta);
  if (_alguna(t, ['mensaje', 'whatsapp', 'cobrarle', 'recordatorio', 'escribele', 'escribirle'])) {
    return Intencion.mensajeCliente;
  }
  if (_alguna(t, ['debe', 'deuda', 'fiad', 'por cobrar', 'pendiente', 'cobros', 'cartera'])) {
    return Intencion.quienDebe;
  }
  if ((t.contains('client') && _alguna(t, ['mejor', 'frecuente', 'top', 'compra'])) ||
      _alguna(t, ['mas me compra', 'mas me compran'])) {
    return Intencion.mejoresClientes;
  }
  if (_alguna(t, ['gast', 'egreso', 'compre'])) return Intencion.gastosMes;
  if (_alguna(t, ['vend', 'venta', 'ingres', 'factur'])) {
    if (t.contains('hoy')) return Intencion.ventasHoy;
    if (t.contains('semana')) return Intencion.ventasSemana;
    return Intencion.ventasMes;
  }
  if (_alguna(t, ['como voy', 'resumen', 'utilidad', 'ganancia', 'gane', 'este mes', 'balance'])) {
    return Intencion.resumen;
  }
  return Intencion.general;
}

String _n(int n, String uno, String varios) => n == 1 ? '1 $uno' : '$n $varios';

/// Busca en la pregunta el nombre de un cliente guardado.
ClienteSaldo? clienteMencionado(String pregunta, List<ClienteSaldo> clientes) {
  final t = ' ${normalizarTexto(pregunta)} ';
  ClienteSaldo? porPrimerNombre;
  for (final c in clientes) {
    final nombre = normalizarTexto(c.nombre);
    if (nombre.isEmpty) continue;
    if (t.contains(' $nombre ')) return c;
    final primero = normalizarTexto(primerNombre(c.nombre));
    if (primero.length >= 3 && t.contains(' $primero ')) {
      porPrimerNombre ??= c;
    }
  }
  return porPrimerNombre;
}

/// Mensaje sugerido para enviar por WhatsApp (respaldo sin conexión).
String mensajeSugerido(ClienteSaldo c) {
  final nombre = primerNombre(c.nombre);
  if (c.saldo > 0) {
    return 'Hola $nombre, ¿cómo está? Le escribimos para recordarle que tiene '
        'un saldo pendiente de ${cop(c.saldo)} con nosotros. Cuando pueda, nos '
        'confirma por aquí la fecha de pago. ¡Muchas gracias!';
  }
  return 'Hola $nombre, ¿cómo está? Queremos agradecerle por preferirnos y '
      'contarle que estamos atentos a lo que necesite. ¡Que tenga un buen día!';
}

Uri enlaceWhatsApp(String telefono, String mensaje) =>
    Uri.parse('https://wa.me/$telefono?text=${Uri.encodeComponent(mensaje)}');

RespuestaLocal responderLocal(String pregunta, DatosAsistente d) {
  final r = d.mes;
  switch (detectarIntencion(pregunta)) {
    case Intencion.ventasHoy:
      return RespuestaLocal(d.nVentasHoy == 0
          ? 'Hoy todavía no has registrado ventas.'
          : 'Hoy llevas ${cop(d.ventasHoy)} en ${_n(d.nVentasHoy, 'venta', 'ventas')}.');
    case Intencion.ventasSemana:
      return RespuestaLocal(d.nVentasSemana == 0
          ? 'Esta semana (desde el lunes) todavía no has registrado ventas.'
          : 'Esta semana (desde el lunes) llevas ${cop(d.ventasSemana)} en '
              '${_n(d.nVentasSemana, 'venta', 'ventas')}.');
    case Intencion.ventasMes:
      return RespuestaLocal(r.nIngresos == 0
          ? 'Este mes todavía no has registrado ventas.'
          : 'Este mes llevas ventas por ${cop(r.ingresos)} en '
              '${_n(r.nIngresos, 'venta', 'ventas')}. Venta promedio: '
              '${cop(r.ticketPromedio)}.');
    case Intencion.quienDebe:
      final deben = d.deudores;
      if (deben.isEmpty) {
        return const RespuestaLocal('Nadie te debe en este momento. ¡Muy bien!');
      }
      final total = deben.fold<double>(0, (s, c) => s + c.saldo);
      final lineas = deben.take(5).map((c) => '• ${c.nombre}: ${cop(c.saldo)}');
      final mas = deben.length > 5 ? '\n…y ${deben.length - 5} más.' : '';
      return RespuestaLocal(
          'Te deben ${cop(total)} entre ${_n(deben.length, 'cliente', 'clientes')}:\n'
          '${lineas.join('\n')}$mas\n\n'
          'Puedes pedirme: «mensaje para cobrarle a ${primerNombre(deben.first.nombre)}».');
    case Intencion.mejoresClientes:
      if (d.topClientes.isEmpty) {
        return const RespuestaLocal(
            'Este mes aún no hay ventas asociadas a clientes. Al registrar una '
            'venta, elige el cliente para ver aquí a tus mejores clientes.');
      }
      var i = 0;
      final l = d.topClientes.map((c) => '${++i}. ${c.nombre}: ${cop(c.total)}');
      return RespuestaLocal('Tus mejores clientes este mes:\n${l.join('\n')}');
    case Intencion.gastosMes:
      if (r.nEgresos == 0) {
        return const RespuestaLocal('Este mes todavía no has registrado gastos.');
      }
      final pct = r.ingresos > 0
          ? ' Equivalen al ${(r.egresos / r.ingresos * 100).round()}% de tus ventas.'
          : '';
      return RespuestaLocal('Este mes llevas gastos por ${cop(r.egresos)} en '
          '${_n(r.nEgresos, 'movimiento', 'movimientos')}.$pct');
    case Intencion.mensajeCliente:
      final c = clienteMencionado(pregunta, d.clientes);
      if (c == null) {
        final deben = d.deudores;
        final ejemplo = deben.isNotEmpty
            ? primerNombre(deben.first.nombre)
            : (d.clientes.isNotEmpty ? primerNombre(d.clientes.first.nombre) : 'Ana');
        return RespuestaLocal('¿Para cuál cliente? Escribe por ejemplo: '
            '«mensaje para cobrarle a $ejemplo».');
      }
      final msg = mensajeSugerido(c);
      if (c.telefono.isEmpty) {
        return RespuestaLocal('Mensaje sugerido para ${c.nombre}:\n\n$msg\n\n'
            'Este cliente no tiene celular registrado; agrégalo en Clientes '
            'para enviarlo por WhatsApp.');
      }
      return RespuestaLocal('Mensaje sugerido para ${c.nombre}:\n\n$msg',
          telefono: c.telefono, mensajeWhatsApp: msg);
    case Intencion.resumen:
    case Intencion.general:
      final cobrar = r.porCobrar > 0
          ? ' Tienes ${cop(r.porCobrar)} por cobrar.'
          : '';
      return RespuestaLocal('${resumenLocal(r)}$cobrar');
  }
}

/// Resumen del mes con un consejo según el margen.
String resumenLocal(Resumen r) {
  if (r.movimientos == 0) {
    return 'Aún no hay movimientos este mes. Registra tus ventas y gastos '
        'para ver aquí tu resumen.';
  }
  final pct = (r.margen * 100).round();
  final base = 'Este mes llevas ventas por ${cop(r.ingresos)} y gastos de '
      '${cop(r.egresos)}. Tu utilidad es ${cop(r.utilidad)} (margen $pct%).';
  final String consejo;
  if (r.utilidad < 0) {
    consejo = 'Tus gastos superan tus ingresos: revisa primero los gastos '
        'más grandes y pospón los que no sean urgentes.';
  } else if (r.margen < 0.2) {
    consejo = 'Tu margen es bajo: revisa precios o reduce costos para '
        'mejorar la utilidad.';
  } else {
    consejo = 'Buen margen. Considera reservar parte de la utilidad y '
        'contactar a tus clientes frecuentes por WhatsApp.';
  }
  final ticket =
      r.nIngresos > 0 ? ' Venta promedio: ${cop(r.ticketPromedio)}.' : '';
  return '$base$ticket $consejo';
}
