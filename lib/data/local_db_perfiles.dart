part of 'local_db.dart';

/// Perfiles con PIN del celular compartido: crear, cambiar el PIN, quitar,
/// entrar (con bloqueo por intentos fallidos) y salir. Viven solo en este
/// equipo; el PIN se guarda como hash con sal, nunca en claro.
extension LocalDbPerfiles on LocalDb {
  Future<List<Perfil>> perfiles() async => [
        for (final f in await db.query('perfiles', where: 'activo = 1', orderBy: 'nombre COLLATE NOCASE'))
          Perfil.desdeFila(f)
      ];

  /// Crea un perfil. El rol no puede ser mayor que el de la cuenta.
  Future<String> crearPerfil(String nombre, Rol rol, String pin, {int iteraciones = iteracionesPin}) async {
    final n = nombre.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (n.length < 2 || n.length > 40) throw ArgumentError('nombre');
    if (problemaPin(pin) != null) throw ArgumentError('pin');
    if (!rolesParaPerfil(equipo.value).contains(rol)) throw ArgumentError('rol');
    final repetido = await db.query('perfiles',
        where: 'activo = 1 AND nombre = ? COLLATE NOCASE', whereArgs: [n]);
    if (repetido.isNotEmpty) throw StateError('repetido');
    final sal = nuevaSal();
    final id = newId();
    await db.insert('perfiles', {
      'id': id,
      'nombre': n,
      'rol': rolATexto(rol),
      'pin_hash': hashPin(pin, sal, iteraciones: iteraciones),
      'sal': sal,
      'iteraciones': iteraciones,
      'activo': 1,
      'creado': _ahora(),
    });
    _avisar();
    return id;
  }

  Future<void> cambiarPin(String id, String pin, {int iteraciones = iteracionesPin}) async {
    if (problemaPin(pin) != null) throw ArgumentError('pin');
    final sal = nuevaSal();
    await db.update('perfiles',
        {'pin_hash': hashPin(pin, sal, iteraciones: iteraciones), 'sal': sal, 'iteraciones': iteraciones},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Se deja de usar (los movimientos conservan su nombre).
  Future<void> quitarPerfil(String id) async {
    await db.update('perfiles', {'activo': 0}, where: 'id = ?', whereArgs: [id]);
    if (perfilActivo.value?.id == id) perfilActivo.value = null;
    _avisar();
  }

  /// Segundos que faltan para poder intentar de nuevo (0 si ya se puede).
  Future<int> esperaPin() async {
    final hasta = DateTime.tryParse(await ajuste('pin_bloqueo_hasta') ?? '');
    if (hasta == null) return 0;
    final s = hasta.difference(reloj().toUtc()).inSeconds;
    return s > 0 ? s : 0;
  }

  /// Entra con el PIN. Tras [intentosAntesDeEsperar] fallos seguidos hay que
  /// esperar [esperaTrasFallos]. Devuelve true si el PIN es correcto.
  Future<bool> entrarComo(String id, String pin) async {
    final p = await verificarPin(id, pin);
    if (p == null) return false;
    perfilActivo.value = p;
    _avisar();
    return true;
  }

  /// Revisa el PIN de un perfil sin cambiar quién atiende (para que un
  /// supervisor autorice algo). Cuenta los fallos igual que al entrar.
  Future<Perfil?> verificarPin(String id, String pin) async {
    if (await esperaPin() > 0) return null;
    final f = await db.query('perfiles', where: 'id = ? AND activo = 1', whereArgs: [id]);
    if (f.isEmpty) return null;
    final p = Perfil.desdeFila(f.first);
    if (pinCorrecto(pin, p)) {
      await borrarAjuste('pin_fallos');
      await borrarAjuste('pin_bloqueo_hasta');
      return p;
    }
    final fallos = int.parse(await ajuste('pin_fallos') ?? '0') + 1;
    if (fallos >= intentosAntesDeEsperar) {
      await setAjuste('pin_bloqueo_hasta', isoUtc(reloj().add(esperaTrasFallos)));
      await borrarAjuste('pin_fallos');
    } else {
      await setAjuste('pin_fallos', '$fallos');
    }
    return null;
  }

  /// Quien maneja la cuenta entra sin perfil (por ejemplo, el dueño que
  /// olvidó su PIN, después de confirmar la clave de la cuenta). Lo que
  /// registre no lleva nombre de perfil.
  void entrarComoCuenta() {
    perfilActivo.value = Perfil(id: '', nombre: '', rol: equipo.value.rol, pinHash: '', sal: '');
    _avisar();
  }

  /// Termina el turno de quien atiende: la app vuelve a preguntar quién es.
  void salirPerfil() {
    perfilActivo.value = null;
    _avisar();
  }
}
