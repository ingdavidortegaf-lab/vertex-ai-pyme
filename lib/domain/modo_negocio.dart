/// Cómo trabaja el negocio, según lo que el dueño respondió al empezar.
/// La app se adapta a esto: si solo vende servicios, la pestaña Inventario
/// pasa a llamarse «Servicios»; si no fía, se esconde la cartera; si no usa
/// gramera o lector de códigos, esos botones no estorban.
library;

enum Oferta { productos, servicios, ambos }

class ModoNegocio {
  /// ¿Ya respondió las preguntas del inicio?
  final bool configurado;
  final Oferta oferta;
  final bool fia;
  final bool gramera;
  final bool codigos;
  final bool pedidos;
  final bool avisos;
  const ModoNegocio({
    this.configurado = false,
    this.oferta = Oferta.productos,
    this.fia = true,
    this.gramera = true,
    this.codigos = true,
    this.pedidos = true,
    this.avisos = true,
  });

  bool get vendeProductos => oferta != Oferta.servicios;
  bool get vendeServicios => oferta != Oferta.productos;

  /// Nombre de la pestaña del catálogo.
  String get nombreCatalogo => switch (oferta) {
        Oferta.productos => 'Inventario',
        Oferta.servicios => 'Servicios',
        Oferta.ambos => 'Catálogo',
      };

  /// Unidad por defecto al crear un ítem nuevo.
  String get unidadInicial => oferta == Oferta.servicios ? 'serv' : 'und';

  /// Claves y valores para guardar en la tabla de ajustes.
  Map<String, String> aAjustes() => {
        'modo_configurado': configurado ? '1' : '0',
        'modo_oferta': oferta.name,
        'modo_fia': fia ? '1' : '0',
        'modo_gramera': gramera ? '1' : '0',
        'modo_codigos': codigos ? '1' : '0',
        'modo_pedidos': pedidos ? '1' : '0',
        'modo_avisos': avisos ? '1' : '0',
      };

  /// Lee los ajustes guardados (lo que falte queda con su valor por defecto,
  /// así un celular con una versión anterior sigue funcionando igual).
  factory ModoNegocio.deAjustes(Map<String, String?> a) {
    bool si(String k, bool def) => a[k] == null ? def : a[k] == '1';
    return ModoNegocio(
      configurado: si('modo_configurado', false),
      oferta: Oferta.values.firstWhere((o) => o.name == a['modo_oferta'],
          orElse: () => Oferta.productos),
      fia: si('modo_fia', true),
      gramera: si('modo_gramera', true),
      codigos: si('modo_codigos', true),
      pedidos: si('modo_pedidos', true),
      avisos: si('modo_avisos', true),
    );
  }

  ModoNegocio copia({
    bool? configurado,
    Oferta? oferta,
    bool? fia,
    bool? gramera,
    bool? codigos,
    bool? pedidos,
    bool? avisos,
  }) =>
      ModoNegocio(
        configurado: configurado ?? this.configurado,
        oferta: oferta ?? this.oferta,
        fia: fia ?? this.fia,
        gramera: gramera ?? this.gramera,
        codigos: codigos ?? this.codigos,
        pedidos: pedidos ?? this.pedidos,
        avisos: avisos ?? this.avisos,
      );
}

/// Sugerencias según el tipo de negocio elegido (el dueño puede cambiarlas).
ModoNegocio sugerenciaPorTipo(String tipo) => switch (tipo) {
      'Restaurante o comidas' =>
        const ModoNegocio(oferta: Oferta.ambos, gramera: false, codigos: false),
      'Peluquería o belleza' ||
      'Taller o reparaciones' ||
      'Servicios profesionales' =>
        const ModoNegocio(
            oferta: Oferta.servicios,
            gramera: false,
            codigos: false,
            pedidos: false),
      'Droguería' || 'Ferretería' => const ModoNegocio(gramera: false),
      _ => const ModoNegocio(),
    };
