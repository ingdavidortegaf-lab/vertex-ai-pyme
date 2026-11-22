/// Ejemplos para las casillas según el tipo de negocio: una licorera ve
/// «Aguardiente 750 ml», una droguería «Acetaminofén 500 mg». Así el
/// dueño entiende enseguida qué escribir en cada campo.
library;

class Ejemplos {
  /// Producto o servicio típico (casilla «Nombre» del inventario).
  final String producto;

  /// Lo que se escribe en el concepto de una venta rápida.
  final String venta;

  /// Un gasto común del negocio.
  final String gasto;

  /// Un proveedor típico.
  final String proveedor;

  /// Un cliente que es empresa.
  final String empresa;

  /// Pagos fijos propios de este negocio (además de arriendo, luz, agua e
  /// internet, que tienen todos).
  final List<String> fijos;

  const Ejemplos({
    required this.producto,
    required this.venta,
    required this.gasto,
    required this.proveedor,
    this.empresa = 'Constructora Horizonte S.A.S.',
    this.fijos = const [],
  });
}

/// Pagos fijos que tiene casi cualquier negocio.
const fijosComunes = ['Arriendo del local', 'Luz', 'Agua', 'Internet'];

const _general = Ejemplos(
  producto: 'Arroz Diana 500 g',
  venta: '2 panelas y 1 aceite',
  gasto: 'Bolsas y empaques',
  proveedor: 'Distribuidora Central',
  fijos: ['Gas', 'Pago al ayudante'],
);

const _porTipo = <String, Ejemplos>{
  'Tienda o minimercado': _general,
  'Tienda de todo un poco': _general,
  'Panadería o cafetería': Ejemplos(
    producto: 'Pan de queso',
    venta: '10 panes y 2 tintos',
    gasto: 'Bulto de harina',
    proveedor: 'Molino de Harinas San José',
    fijos: ['Gas', 'Pago al panadero'],
  ),
  'Frutas y verduras': Ejemplos(
    producto: 'Plátano hartón (kg)',
    venta: '2 kg de tomate',
    gasto: 'Flete desde la plaza',
    proveedor: 'Bodega de la plaza de mercado',
    fijos: ['Puesto en la plaza'],
  ),
  'Carnicería o pollo': Ejemplos(
    producto: 'Carne de res para asar (lb)',
    venta: '2 lb de pechuga',
    gasto: 'Hielo y bolsas',
    proveedor: 'Frigorífico Regional',
    fijos: ['Gas', 'Mantenimiento de la nevera'],
  ),
  'Droguería': Ejemplos(
    producto: 'Acetaminofén 500 mg x 10',
    venta: 'Suero oral y curitas',
    gasto: 'Bolsas y facturero',
    proveedor: 'Droguería Mayorista Central',
    empresa: 'IPS Salud Integral S.A.S.',
    fijos: ['Regente de farmacia', 'Software de facturación'],
  ),
  'Ferretería': Ejemplos(
    producto: 'Cemento gris 50 kg',
    venta: '1 galón de pintura y brocha',
    gasto: 'Flete de la mercancía',
    proveedor: 'Ferretería Mayorista El Constructor',
    fijos: ['Pago al ayudante', 'Cuota del préstamo'],
  ),
  'Agro y veterinaria': Ejemplos(
    producto: 'Concentrado para ganado 40 kg',
    venta: '2 bultos de concentrado',
    gasto: 'Flete a la vereda',
    proveedor: 'Agropecuaria La Pradera',
    empresa: 'Hato La Esperanza S.A.S.',
    fijos: ['Pago al ayudante'],
  ),
  'Licorera': Ejemplos(
    producto: 'Aguardiente 750 ml',
    venta: '1 canasta de cerveza y hielo',
    gasto: 'Bolsas de hielo',
    proveedor: 'Distribuidora de Licores Central',
    empresa: 'Eventos y Fiestas S.A.S.',
    fijos: ['Música (derechos de autor)', 'Pago al mesero', 'Licencia de funcionamiento'],
  ),
  'Restaurante o comidas': Ejemplos(
    producto: 'Almuerzo ejecutivo',
    venta: '3 almuerzos para llevar',
    gasto: 'Mercado de la plaza',
    proveedor: 'Fruver La Cosecha',
    empresa: 'Servicios Industriales S.A.S.',
    fijos: ['Gas', 'Pago a la cocinera'],
  ),
  'Comidas rápidas y domicilios': Ejemplos(
    producto: 'Hamburguesa sencilla',
    venta: '2 perros y 1 gaseosa',
    gasto: 'Pan y salsas',
    proveedor: 'Panificadora Central',
    fijos: ['Gas', 'Domiciliario'],
  ),
  'Ropa y calzado': Ejemplos(
    producto: 'Jean dama talla 8',
    venta: 'Camiseta y gorra',
    gasto: 'Bolsas con logo',
    proveedor: 'Confecciones Medellín',
    fijos: ['Pago a la vendedora'],
  ),
  'Papelería y variedades': Ejemplos(
    producto: 'Cuaderno 100 hojas',
    venta: '5 fotocopias y 1 lapicero',
    gasto: 'Resma de papel',
    proveedor: 'Papelería Mayorista Central',
    empresa: 'Colegio San José',
    fijos: ['Alquiler de la fotocopiadora'],
  ),
  'Celulares y tecnología': Ejemplos(
    producto: 'Cargador tipo C',
    venta: 'Vidrio templado y forro',
    gasto: 'Repuestos de pantalla',
    proveedor: 'Importadora Tecno Bogotá',
    fijos: ['Pago al técnico'],
  ),
  'Artesanías y emprendimiento': Ejemplos(
    producto: 'Bolso tejido a mano',
    venta: 'Mochila tejida',
    gasto: 'Hilos y cuero',
    proveedor: 'Talabartería El Artesano',
    fijos: ['Puesto en la feria'],
  ),
  'Peluquería o belleza': Ejemplos(
    producto: 'Corte de cabello',
    venta: 'Corte y barba',
    gasto: 'Tintes y cuchillas',
    proveedor: 'Distribuidora de Belleza Central',
    fijos: ['Pago al estilista'],
  ),
  'Taller o reparaciones': Ejemplos(
    producto: 'Cambio de aceite',
    venta: 'Despinchada y revisión',
    gasto: 'Repuestos',
    proveedor: 'Repuestos El Motor',
    empresa: 'Transportes Rápidos S.A.S.',
    fijos: ['Pago al ayudante'],
  ),
  'Lavadero de carros y motos': Ejemplos(
    producto: 'Lavada de moto',
    venta: 'Lavada general camioneta',
    gasto: 'Shampoo y cera',
    proveedor: 'Químicos y Aseo Central',
    fijos: ['Pago al lavador'],
  ),
  'Transporte o mensajería': Ejemplos(
    producto: 'Carrera urbana',
    venta: 'Domicilio al centro',
    gasto: 'Gasolina',
    proveedor: 'Estación de servicio',
    empresa: 'Comercializadora Central S.A.S.',
    fijos: ['Cuota de la moto', 'Plan de datos del celular'],
  ),
  'Hospedaje': Ejemplos(
    producto: 'Habitación doble por noche',
    venta: '2 noches habitación sencilla',
    gasto: 'Lavandería de sábanas',
    proveedor: 'Lavandería Industrial Central',
    empresa: 'Constructora Horizonte S.A.S.',
    fijos: ['Gas', 'Televisión por cable', 'Pago a la camarera'],
  ),
  'Servicios profesionales': Ejemplos(
    producto: 'Asesoría contable (hora)',
    venta: 'Declaración de renta',
    gasto: 'Papelería',
    proveedor: 'Papelería El Estudiante',
    fijos: ['Software contable'],
  ),
};

/// Ejemplos para el tipo de negocio (o los generales si no se conoce).
Ejemplos ejemplosPara(String tipo) => _porTipo[tipo] ?? _general;

/// Pagos fijos sugeridos para el tipo de negocio, sin repetir.
List<String> fijosSugeridos(String tipo) =>
    {...fijosComunes, ...ejemplosPara(tipo).fijos}.toList();
