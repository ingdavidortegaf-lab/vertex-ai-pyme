/// Reglas de los avisos en el celular (sin pantallas, para poder probarlas).
///
/// Cada aviso se manda UNA sola vez por situación: se recuerda qué productos
/// ya se avisaron como agotados o bajos; si el producto se vuelve a surtir,
/// sale de la lista y podrá avisarse otra vez cuando se acabe de nuevo.
library;

import 'codigos.dart';
import 'formato.dart';
import 'resumen.dart';

class Aviso {
  final int id;
  final String canal; // 'inventario', 'cobros', 'metas', 'sistema'
  final String titulo;
  final String cuerpo;
  const Aviso(this.id, this.canal, this.titulo, this.cuerpo);
}

/// Estado recordado entre una revisión y otra.
class MemoriaAvisos {
  final Set<String> agotados;
  final Set<String> bajos;
  final String metaMes; // 'AAAA-MM' del último aviso de meta cumplida
  final String carteraDia; // 'AAAA-MM-DD' del último aviso de cartera
  final int errores; // registros con error de envío ya avisados
  final String proveedoresDia; // 'AAAA-MM-DD' del último aviso de pagos a proveedores
  const MemoriaAvisos({
    this.proveedoresDia = '',
    this.agotados = const {},
    this.bajos = const {},
    this.metaMes = '',
    this.carteraDia = '',
    this.errores = 0,
  });
}

String _lista(List<String> l, [int max = 3]) => l.length <= max
    ? l.join(', ')
    : '${l.take(max).join(', ')} y ${l.length - max} más';

String _mes(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
String _diaClave(DateTime d) =>
    '${_mes(d)}-${d.day.toString().padLeft(2, '0')}';

/// Revisa la situación del negocio y devuelve los avisos nuevos y la
/// memoria actualizada.
({List<Aviso> avisos, MemoriaAvisos memoria}) revisarAvisos({
  required MemoriaAvisos previa,
  required List<ProductoStock> productos,
  required DateTime ahora,
  double ventasMes = 0,
  double metaMes = 0,
  int clientesVencidos = 0,
  double saldoVencido = 0,
  int erroresEnvio = 0,
  bool avisarCartera = true,
  int pagosPorVencer = 0, // cuentas con proveedores que vencen en 3 días o ya vencieron
  double saldoPorVencer = 0,
}) {
  final avisos = <Aviso>[];
  final agotados = {
    for (final p in productos)
      if (p.agotado) p.id
  };
  final bajos = {
    for (final p in productos)
      if (p.bajo) p.id
  };
  final nombre = {for (final p in productos) p.id: p.nombre};

  final nuevosAgotados = [
    for (final id in agotados)
      if (!previa.agotados.contains(id)) nombre[id]!
  ];
  if (nuevosAgotados.length == 1) {
    avisos.add(Aviso(1, 'inventario', 'Se agotó ${nuevosAgotados.first}',
        'Ya no queda. Toca para armar el pedido al proveedor.'));
  } else if (nuevosAgotados.length > 1) {
    avisos.add(Aviso(
        1,
        'inventario',
        'Se agotaron ${nuevosAgotados.length} productos',
        _lista(nuevosAgotados)));
  }

  final nuevosBajos = [
    for (final p in productos)
      if (bajos.contains(p.id) && !previa.bajos.contains(p.id)) p
  ];
  if (nuevosBajos.length == 1) {
    final p = nuevosBajos.first;
    avisos.add(Aviso(2, 'inventario', 'Se está acabando ${p.nombre}',
        'Quedan ${cantidadConUnidad(p.stock, p.unidad)} (avisas en ${cantidadConUnidad(p.minimo, p.unidad)}).'));
  } else if (nuevosBajos.length > 1) {
    avisos.add(Aviso(
        2,
        'inventario',
        '${nuevosBajos.length} productos por acabarse',
        _lista([for (final p in nuevosBajos) p.nombre])));
  }

  var metaClave = previa.metaMes;
  if (metaMes > 0 && ventasMes >= metaMes && previa.metaMes != _mes(ahora)) {
    metaClave = _mes(ahora);
    avisos.add(Aviso(3, 'metas', '¡Cumpliste la meta del mes!',
        'Llevas ${cop(ventasMes)} de ${cop(metaMes)}. ¡Felicitaciones!'));
  }

  var carteraClave = previa.carteraDia;
  if (avisarCartera &&
      clientesVencidos > 0 &&
      previa.carteraDia != _diaClave(ahora) &&
      ahora.hour >= 8) {
    carteraClave = _diaClave(ahora);
    avisos.add(Aviso(
        4,
        'cobros',
        clientesVencidos == 1
            ? '1 cliente debe hace más de 30 días'
            : '$clientesVencidos clientes deben hace más de 30 días',
        'Por cobrar: ${cop(saldoVencido)}. Envíales la cuenta de cobro desde «Cartera».'));
  }

  var proveedoresClave = previa.proveedoresDia;
  if (pagosPorVencer > 0 && previa.proveedoresDia != _diaClave(ahora) && ahora.hour >= 8) {
    proveedoresClave = _diaClave(ahora);
    avisos.add(Aviso(
        6,
        'cobros',
        pagosPorVencer == 1
            ? 'Tienes 1 pago a proveedor por vencer'
            : 'Tienes $pagosPorVencer pagos a proveedores por vencer',
        'Suman ${cop(saldoPorVencer)}. Míralos en «Lo que debo».'));
  }

  if (erroresEnvio > previa.errores) {
    avisos.add(const Aviso(
        5,
        'sistema',
        'Hay datos que no se pudieron subir a la nube',
        'Siguen guardados en el celular. Revisa en el menú ⋮ → «Sincronizar».'));
  }

  return (
    avisos: avisos,
    memoria: MemoriaAvisos(
      agotados: agotados,
      bajos: bajos,
      metaMes: metaClave,
      carteraDia: carteraClave,
      errores: erroresEnvio,
      proveedoresDia: proveedoresClave,
    ),
  );
}
