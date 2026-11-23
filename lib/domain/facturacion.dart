// Factura electrónica: modelo, cálculo y la interfaz con el proveedor
// tecnológico. La app NO trae un proveedor real ni inventa reglas: los datos
// del emisor, la resolución de numeración y el porcentaje de IVA de cada
// producto los escribe el dueño; el CUFE y el código QR los entrega el
// proveedor cuando la DIAN acepta la factura.

/// Estado de una factura electrónica en la cola.
enum EstadoFE {
  /// En la cola del celular, todavía sin enviar (por ejemplo, sin internet).
  pendiente,

  /// El proveedor la recibió y está esperando la respuesta de la DIAN.
  enviado,

  /// La DIAN la aceptó: tiene CUFE y QR.
  aceptado,

  /// La DIAN o el proveedor la rechazó (el motivo queda en el mensaje).
  rechazado,
}

String estadoFETexto(EstadoFE e) => switch (e) {
      EstadoFE.pendiente => 'Pendiente de envío',
      EstadoFE.enviado => 'Enviada, esperando a la DIAN',
      EstadoFE.aceptado => 'Aceptada por la DIAN',
      EstadoFE.rechazado => 'Rechazada',
    };

EstadoFE estadoFEDesdeTexto(String? s) =>
    EstadoFE.values.firstWhere((e) => e.name == s, orElse: () => EstadoFE.pendiente);

/// IVA de un producto que todavía no se ha definido (no se inventa una tarifa).
const ivaSinDefinir = -1.0;

/// ¿El porcentaje de IVA es válido? (−1 = sin definir).
bool ivaValido(double v) => v == ivaSinDefinir || (v.isFinite && v >= 0 && v <= 100);

/// Datos del emisor (el negocio) y su resolución de numeración. Todo lo
/// escribe el dueño tal como aparece en sus documentos de la DIAN.
class DatosEmisor {
  final String razonSocial;
  final String nit; // sin dígito de verificación
  final String dv;
  final String responsabilidad; // tal como la tenga en el RUT
  final String direccion;
  final String municipio;
  final String correo;
  final String telefono;
  final String resolucion; // número de la resolución de facturación
  final String prefijo;
  final int desde;
  final int hasta;
  final DateTime? vigenteHasta;
  const DatosEmisor({
    this.razonSocial = '',
    this.nit = '',
    this.dv = '',
    this.responsabilidad = '',
    this.direccion = '',
    this.municipio = '',
    this.correo = '',
    this.telefono = '',
    this.resolucion = '',
    this.prefijo = '',
    this.desde = 0,
    this.hasta = 0,
    this.vigenteHasta,
  });

  /// Claves en ajustes (solo en este celular).
  static const claves = [
    'fe_razon_social', 'fe_nit', 'fe_dv', 'fe_responsabilidad', 'fe_direccion', 'fe_municipio',
    'fe_correo', 'fe_telefono', 'fe_resolucion', 'fe_prefijo', 'fe_desde', 'fe_hasta', 'fe_vigente_hasta',
  ];

  factory DatosEmisor.desdeAjustes(Map<String, String?> a) => DatosEmisor(
        razonSocial: a['fe_razon_social'] ?? '',
        nit: a['fe_nit'] ?? '',
        dv: a['fe_dv'] ?? '',
        responsabilidad: a['fe_responsabilidad'] ?? '',
        direccion: a['fe_direccion'] ?? '',
        municipio: a['fe_municipio'] ?? '',
        correo: a['fe_correo'] ?? '',
        telefono: a['fe_telefono'] ?? '',
        resolucion: a['fe_resolucion'] ?? '',
        prefijo: a['fe_prefijo'] ?? '',
        desde: int.tryParse(a['fe_desde'] ?? '') ?? 0,
        hasta: int.tryParse(a['fe_hasta'] ?? '') ?? 0,
        vigenteHasta: DateTime.tryParse(a['fe_vigente_hasta'] ?? ''),
      );

  Map<String, String> aAjustes() => {
        'fe_razon_social': razonSocial.trim(),
        'fe_nit': nit.replaceAll(RegExp(r'\D'), ''),
        'fe_dv': dv.trim(),
        'fe_responsabilidad': responsabilidad.trim(),
        'fe_direccion': direccion.trim(),
        'fe_municipio': municipio.trim(),
        'fe_correo': correo.trim(),
        'fe_telefono': telefono.trim(),
        'fe_resolucion': resolucion.trim(),
        'fe_prefijo': prefijo.trim().toUpperCase(),
        'fe_desde': '$desde',
        'fe_hasta': '$hasta',
        'fe_vigente_hasta': vigenteHasta == null ? '' : _fecha(vigenteHasta!),
      };

  /// Lo que falta para poder facturar (vacío si está completo).
  List<String> faltantes() => [
        if (razonSocial.trim().isEmpty) 'razón social',
        if (nit.replaceAll(RegExp(r'\D'), '').length < 6) 'NIT',
        if (dv.trim().isEmpty) 'dígito de verificación',
        if (direccion.trim().isEmpty) 'dirección',
        if (municipio.trim().isEmpty) 'municipio',
        if (correo.trim().isEmpty) 'correo',
        if (resolucion.trim().isEmpty) 'número de la resolución',
        if (desde <= 0 || hasta < desde) 'rango de numeración (desde y hasta)',
        if (vigenteHasta == null) 'fecha de vigencia de la resolución',
      ];

  Map<String, Object?> aMapa() => {
        'razon_social': razonSocial,
        'nit': nit,
        'dv': dv,
        'responsabilidad': responsabilidad,
        'direccion': direccion,
        'municipio': municipio,
        'correo': correo,
        'telefono': telefono,
        'resolucion': resolucion,
        'prefijo': prefijo,
      };
}

String _fecha(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Próximo número de la resolución. Error (texto) si se acabó o venció.
({int? numero, String? error}) siguienteNumero(DatosEmisor e, int? ultimoUsado, DateTime hoy) {
  if (e.vigenteHasta != null) {
    final fin = DateTime(e.vigenteHasta!.year, e.vigenteHasta!.month, e.vigenteHasta!.day, 23, 59, 59);
    if (hoy.isAfter(fin)) return (numero: null, error: 'La resolución de numeración está vencida');
  }
  final n = ultimoUsado == null || ultimoUsado < e.desde ? e.desde : ultimoUsado + 1;
  if (n > e.hasta) return (numero: null, error: 'Se acabó la numeración autorizada');
  return (numero: n, error: null);
}

/// Una línea de la factura. El precio es el que pagó el cliente (con IVA
/// incluido, como se registró la venta).
class LineaFE {
  final String descripcion;
  final double cantidad;
  final String unidad;
  final double precioConIva;
  final double ivaPct;
  const LineaFE({
    required this.descripcion,
    required this.cantidad,
    required this.unidad,
    required this.precioConIva,
    required this.ivaPct,
  });

  double get total => _r(cantidad * precioConIva);
  double get base => _r(total / (1 + ivaPct / 100));
  double get iva => _r(total - base);

  Map<String, Object?> aMapa() => {
        'descripcion': descripcion,
        'cantidad': cantidad,
        'unidad': unidad,
        'precio_con_iva': precioConIva,
        'iva_pct': ivaPct,
        'base': base,
        'iva': iva,
        'total': total,
      };
}

double _r(double v) => (v * 100).roundToDouble() / 100;

/// Comprador. La factura electrónica necesita su documento.
class CompradorFE {
  final String nombre;
  final String tipoDoc;
  final String documento;
  final String correo;
  const CompradorFE({required this.nombre, required this.tipoDoc, required this.documento, this.correo = ''});

  Map<String, Object?> aMapa() => {'nombre': nombre, 'tipo_doc': tipoDoc, 'documento': documento, 'correo': correo};
}

/// Lo que se le entrega al proveedor para emitir.
class FacturaElectronica {
  final String id;
  final String ventaId;
  final String numero; // prefijo + consecutivo
  final DateTime fecha;
  final DatosEmisor emisor;
  final CompradorFE comprador;
  final List<LineaFE> lineas;
  final List<Map<String, Object?>> pagos;
  const FacturaElectronica({
    required this.id,
    required this.ventaId,
    required this.numero,
    required this.fecha,
    required this.emisor,
    required this.comprador,
    required this.lineas,
    this.pagos = const [],
  });

  double get total => _r(lineas.fold(0.0, (s, l) => s + l.total));
  double get base => _r(lineas.fold(0.0, (s, l) => s + l.base));
  double get iva => _r(lineas.fold(0.0, (s, l) => s + l.iva));

  /// IVA agrupado por porcentaje (base e impuesto de cada uno).
  Map<double, ({double base, double iva})> get ivaPorTarifa {
    final m = <double, ({double base, double iva})>{};
    for (final l in lineas) {
      final a = m[l.ivaPct] ?? (base: 0.0, iva: 0.0);
      m[l.ivaPct] = (base: _r(a.base + l.base), iva: _r(a.iva + l.iva));
    }
    return m;
  }

  Map<String, Object?> aMapa() => {
        'id': id,
        'venta_id': ventaId,
        'numero': numero,
        'fecha': fecha.toUtc().toIso8601String(),
        'emisor': emisor.aMapa(),
        'comprador': comprador.aMapa(),
        'lineas': [for (final l in lineas) l.aMapa()],
        'pagos': pagos,
        'base': base,
        'iva': iva,
        'total': total,
      };
}

/// Lo que responde el proveedor.
class RespuestaFE {
  final EstadoFE estado;
  final String? idExterno;
  final String? cufe;
  final String? qr; // contenido del QR tal como lo entrega el proveedor
  final String mensaje;
  const RespuestaFE({required this.estado, this.idExterno, this.cufe, this.qr, this.mensaje = ''});
}

/// El proveedor no respondió (sin internet, caído…): la factura sigue en la
/// cola y se reintenta.
class SinRespuestaFE implements Exception {
  final String motivo;
  const SinRespuestaFE([this.motivo = 'sin conexión']);
}

/// Proveedor tecnológico autorizado por la DIAN. Cada proveedor real se
/// conecta implementando esta interfaz (su clave va por --dart-define o en
/// el servidor, nunca en el código).
abstract class ProveedorFacturacion {
  String get nombre;

  /// ¿Está listo para emitir? (credenciales, ambiente…)
  bool get configurado;

  /// Envía la factura. Lanza [SinRespuestaFE] si no hubo respuesta.
  Future<RespuestaFE> emitir(FacturaElectronica f);

  /// Pregunta por una factura enviada. Lanza [SinRespuestaFE] si no hubo respuesta.
  Future<RespuestaFE> consultar(String idExterno);
}

/// Sin proveedor contratado: nada se envía y las facturas esperan en la cola.
class SinProveedor implements ProveedorFacturacion {
  const SinProveedor();
  @override
  String get nombre => 'Sin proveedor';
  @override
  bool get configurado => false;
  @override
  Future<RespuestaFE> emitir(FacturaElectronica f) async => throw const SinRespuestaFE('sin proveedor');
  @override
  Future<RespuestaFE> consultar(String idExterno) async => throw const SinRespuestaFE('sin proveedor');
}

/// Una factura en la cola, como se guarda en el celular.
class FacturaEmitida {
  final String id;
  final String ventaId;
  final String numero;
  final EstadoFE estado;
  final String? cufe;
  final String? qr;
  final String mensaje;
  final DateTime creado;
  final double total;
  final String comprador;
  const FacturaEmitida({
    required this.id,
    required this.ventaId,
    required this.numero,
    required this.estado,
    this.cufe,
    this.qr,
    this.mensaje = '',
    required this.creado,
    this.total = 0,
    this.comprador = '',
  });

  bool get aceptada => estado == EstadoFE.aceptado && (cufe ?? '').isNotEmpty;

  factory FacturaEmitida.desdeFila(Map<String, Object?> f) => FacturaEmitida(
        id: f['id'] as String,
        ventaId: f['venta_id'] as String,
        numero: f['numero'] as String,
        estado: estadoFEDesdeTexto(f['estado'] as String?),
        cufe: f['cufe'] as String?,
        qr: f['qr'] as String?,
        mensaje: (f['mensaje'] as String?) ?? '',
        creado: DateTime.parse(f['creado'] as String).toLocal(),
        total: (f['total'] as num?)?.toDouble() ?? 0,
        comprador: (f['comprador'] as String?) ?? '',
      );
}
