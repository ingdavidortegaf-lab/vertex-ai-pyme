part of 'local_db.dart';

/// Modo y perfil del negocio y datos para recibir pagos.
extension LocalDbNegocio on LocalDb {
  // ----------------------------------------------------------- herramientas
  /// Lee el modo del negocio guardado y avisa a las pantallas.
  Future<ModoNegocio> cargarModo() async {
    final r = await db.query('ajustes', where: "clave LIKE 'modo_%'");
    final m = ModoNegocio.deAjustes(
        {for (final x in r) x['clave'] as String: x['valor'] as String?});
    modo.value = m;
    tipoNegocio.value = await ajuste('negocio_tipo') ?? '';
    await _cargarContexto();
    return m;
  }

  Future<void> guardarModo(ModoNegocio m) async {
    await db.transaction((t) async {
      for (final e in m.aAjustes().entries) {
        await t.insert('ajustes', {'clave': e.key, 'valor': e.value},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    modo.value = m;
    _avisar();
  }

  /// Cuentas del negocio para recibir transferencias.
  Future<DatosPago> datosPago() async => DatosPago(
        nequi: await ajuste('pago_nequi') ?? '',
        daviplata: await ajuste('pago_daviplata') ?? '',
        bancolombia: await ajuste('pago_bancolombia') ?? '',
        llave: await ajuste('pago_llave') ?? '',
      );

  Future<void> guardarDatosPago(DatosPago d) async {
    await setAjuste('pago_nequi', d.nequi.trim());
    await setAjuste('pago_daviplata', d.daviplata.trim());
    await setAjuste('pago_bancolombia', d.bancolombia.trim());
    await setAjuste('pago_llave', d.llave.trim());
    _avisar();
  }

  Future<PerfilNegocio> perfilNegocio() async => PerfilNegocio(
        nombre: await ajuste('negocio_nombre') ?? '',
        tipo: await ajuste('negocio_tipo') ?? '',
        nit: await ajuste('negocio_nit') ?? '',
        direccion: await ajuste('negocio_direccion') ?? '',
        telefono: await ajuste('negocio_telefono') ?? '',
        meta: double.tryParse(await ajuste('negocio_meta') ?? '') ?? 0,
        logo: await ajuste('negocio_logo') ?? '',
      );
}
